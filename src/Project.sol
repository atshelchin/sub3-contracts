// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {DataTypes} from "./DataTypes.sol";
import {ProjectStorage} from "./ProjectStorage.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {IFactory} from "./interfaces/IFactory.sol";
import {IProjectWrite} from "./interfaces/IProjectWrite.sol";

contract Project is IProjectWrite, ProjectStorage, ReentrancyGuard {
    // Reader implementation for view functions
    address public readerImplementation;
    // Events and Errors are defined in IProject interface

    // ==================== Modifiers ====================
    modifier whenInitialized() {
        if (!initialized) revert NotInitialized();
        _;
    }

    modifier validTier(DataTypes.SubscriptionTier tier) {
        if (uint256(tier) > uint256(brandConfig.maxTier)) {
            revert InvalidTier();
        }
        _;
    }

    modifier validPeriod(DataTypes.SubscriptionPeriod period) {
        uint256 periodIndex = uint256(period);
        if (periodIndex > 3 || !brandConfig.enabledPeriods[periodIndex]) {
            revert InvalidPeriod();
        }
        _;
    }

    // ==================== Initialization ====================
    function initialize(
        DataTypes.BrandConfig memory _brandConfig,
        address _factory,
        address _owner,
        uint256[4][4] memory prices
    ) external {
        if (initialized) revert ProjectAlreadyInitialized();
        initialized = true;
        brandConfig = _brandConfig;
        factory = _factory;
        _initializeOwner(_owner);

        // Initialize plans for each enabled tier
        for (uint8 i = 0; i <= brandConfig.maxTier; i++) {
            DataTypes.SubscriptionTier tier = DataTypes.SubscriptionTier(i);
            plans[tier] = DataTypes.SubscriptionPlan({
                enabled: true,
                prices: prices[i],
                features: new string[](0)
            });
        }
    }

    // ==================== Admin Functions ====================

    /**
     * @notice Set subscription plan configuration
     * @dev Only owner can call this function to update pricing and features
     * @param tier Subscription tier to update
     * @param prices Array of prices for [daily, weekly, monthly, yearly]
     * @param features Array of feature descriptions
     */
    function setPlanConfig(
        DataTypes.SubscriptionTier tier,
        uint256[4] memory prices,
        string[] memory features
    ) external onlyOwner whenInitialized validTier(tier) {
        plans[tier].prices = prices;
        plans[tier].features = features;
        plans[tier].enabled = true;

        emit PlanConfigUpdated(
            tier,
            prices,
            brandConfig.tierNames[uint8(tier)],
            features
        );
    }

    /**
     * @notice Update brand configuration (name and symbol cannot be changed)
     * @dev Only owner can update brand settings except name and symbol
     * @param newConfig New brand configuration
     */
    function updateBrandConfig(
        DataTypes.BrandConfig memory newConfig
    ) external onlyOwner whenInitialized {
        // Name and symbol must remain the same
        require(
            keccak256(bytes(newConfig.name)) ==
                keccak256(bytes(brandConfig.name)),
            "Name cannot be changed"
        );
        require(
            keccak256(bytes(newConfig.symbol)) ==
                keccak256(bytes(brandConfig.symbol)),
            "Symbol cannot be changed"
        );

        // Update all configurable fields
        brandConfig.description = newConfig.description;
        brandConfig.logoUri = newConfig.logoUri;
        brandConfig.websiteUrl = newConfig.websiteUrl;
        brandConfig.primaryColor = newConfig.primaryColor;
        brandConfig.maxTier = newConfig.maxTier;
        brandConfig.enabledPeriods = newConfig.enabledPeriods;
        brandConfig.tierNames = newConfig.tierNames;

        emit BrandConfigUpdated(brandConfig.name, brandConfig.symbol);
    }

    /**
     * @notice Withdraw contract balance (excluding pending referral rewards)
     * @dev Only owner can call this function with reentrancy protection
     * @dev Cannot withdraw funds reserved for referral rewards
     * @param to Recipient address
     */
    function withdraw(address to) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();

        // Calculate withdrawable balance (total balance - pending referral rewards)
        uint256 withdrawableBalance = address(this).balance -
            totalPendingReferralRewards;

        _safeTransfer(to, withdrawableBalance);

        emit Withdrawn(to, withdrawableBalance);
    }

    // ==================== Subscription Functions ====================

    /**
     * @notice Subscribe to a service plan (first-time subscribers only)
     * @dev User must never have subscribed before, can optionally provide a referrer
     * @param tier Subscription tier (PRO or MAX)
     * @param period Payment period (MONTHLY or YEARLY)
     * @param referrer Optional referrer address (must have active subscription)
     */
    function subscribe(
        DataTypes.SubscriptionTier tier,
        DataTypes.SubscriptionPeriod period,
        address referrer
    )
        external
        payable
        whenInitialized
        validTier(tier)
        validPeriod(period)
        nonReentrant
    {
        // Check if this is a first-time subscriber (before updating the subscription)
        bool isFirstTimeSubscriber = userSubscriptions[msg.sender].user ==
            address(0);

        // Check first-time subscriber
        if (!isFirstTimeSubscriber) revert AlreadySubscribed();

        // Validate referrer
        address validReferrer;
        if (referrer != address(0) && referrer != msg.sender) {
            if (userSubscriptions[referrer].endTime > block.timestamp) {
                validReferrer = referrer;
            }
        }

        uint256 price = _getPrice(tier, period);
        _validatePayment(price);

        uint256 endTime = block.timestamp + _getDuration(period);

        // Single storage write
        userSubscriptions[msg.sender] = DataTypes.UserSubscription({
            user: msg.sender,
            referrer: validReferrer,
            tier: tier,
            period: period,
            startTime: block.timestamp,
            endTime: endTime,
            paidAmount: msg.value,
            totalRewardsEarned: 0,
            totalSpent: msg.value
        });

        // Update subscriber count and list (only for first-time subscribers)
        if (isFirstTimeSubscriber) {
            subscribersList.push(msg.sender);
            totalSubscribers++;
        }

        // Check if this creates a new referrer (only if valid)
        if (validReferrer != address(0)) {
            // Check if referrer is becoming active for the first time
            if (referralAccounts[validReferrer].referralCount == 0) {
                totalReferrers++;
            }
            // Add to referrer's list of referred users
            referrerToUsers[validReferrer].push(msg.sender);
        }

        // Process payment and rewards
        _processPayment(msg.sender, msg.value);

        // Record operation
        _recordOperation(
            msg.sender,
            DataTypes.OperationType.SUBSCRIBE,
            DataTypes.SubscriptionTier.STARTER, // No previous tier for new subscription
            tier,
            DataTypes.SubscriptionPeriod.DAILY, // No previous period
            period,
            msg.value,
            endTime
        );

        emit Subscribed(msg.sender, tier, period, msg.value, endTime);
    }

    /**
     * @notice Renew expired subscription with flexible tier and period
     * @dev Can only renew after subscription expires, allows changing both tier and period
     * @param tier Subscription tier for renewal
     * @param period Payment period for renewal
     */
    function renew(
        DataTypes.SubscriptionTier tier,
        DataTypes.SubscriptionPeriod period
    )
        external
        payable
        whenInitialized
        validTier(tier)
        validPeriod(period)
        nonReentrant
    {
        DataTypes.UserSubscription storage subscription = userSubscriptions[
            msg.sender
        ];

        _requireSubscriptionExists(msg.sender);
        _requireExpiredSubscription(msg.sender);

        // Store old values for history
        DataTypes.SubscriptionTier oldTier = subscription.tier;
        DataTypes.SubscriptionPeriod oldPeriod = subscription.period;

        uint256 price = _getPrice(tier, period);
        _validatePayment(price);

        // Update subscription - can change both tier and period on renewal
        subscription.tier = tier;
        subscription.period = period;
        subscription.startTime = block.timestamp;
        subscription.endTime = block.timestamp + _getDuration(period);
        subscription.paidAmount = msg.value;
        subscription.totalSpent += msg.value;

        // Process payment and rewards (statistics updated inside)
        _processPayment(msg.sender, msg.value);

        // Record operation
        _recordOperation(
            msg.sender,
            DataTypes.OperationType.RENEW,
            oldTier,
            tier,
            oldPeriod,
            period,
            msg.value,
            subscription.endTime
        );

        emit Renewed(msg.sender, tier, period, msg.value, subscription.endTime);
    }

    /**
     * @notice Upgrade subscription to higher tier with optional period change
     * @dev Extends subscription by one period from current end date with upgraded tier
     * @param newTier New subscription tier (must be higher than current)
     * @param newPeriod New subscription period
     */
    function upgrade(
        DataTypes.SubscriptionTier newTier,
        DataTypes.SubscriptionPeriod newPeriod
    )
        external
        payable
        whenInitialized
        validTier(newTier)
        validPeriod(newPeriod)
        nonReentrant
    {
        DataTypes.UserSubscription storage subscription = userSubscriptions[
            msg.sender
        ];

        _requireActiveSubscription(msg.sender);

        // Validate upgrade
        if (subscription.tier == newTier) revert CannotUpgradeToSameTier();
        if (newTier < subscription.tier) revert InvalidTier();

        // Calculate upgrade cost safely
        uint256 remainingTime = subscription.endTime - block.timestamp;
        uint256 currentPeriodDuration = _getDuration(subscription.period);
        uint256 newPeriodDuration = _getDuration(newPeriod);
        uint256 newTierPrice = _getPrice(newTier, newPeriod);

        // Use the actual amount paid by the user, not current price
        // This ensures fair credit calculation even if prices changed
        uint256 actualPaidAmount = subscription.paidAmount;

        // Calculate costs separately to avoid underflow
        uint256 remainingNewCost = (newTierPrice * remainingTime) /
            newPeriodDuration;
        uint256 fullPeriodCost = newTierPrice;
        uint256 remainingOldCredit = (actualPaidAmount * remainingTime) /
            currentPeriodDuration;

        // Ensure no underflow
        uint256 upgradeCost = remainingNewCost + fullPeriodCost;
        if (remainingOldCredit <= upgradeCost) {
            upgradeCost = upgradeCost - remainingOldCredit;
        } else {
            upgradeCost = 0; // Edge case: credit exceeds cost
        }

        _validatePayment(upgradeCost);

        // Update subscription
        DataTypes.SubscriptionTier oldTier = subscription.tier;
        DataTypes.SubscriptionPeriod oldPeriod = subscription.period;
        subscription.tier = newTier;
        subscription.period = newPeriod;
        subscription.endTime = subscription.endTime + newPeriodDuration;
        // Set paidAmount to the full price of the new tier/period (not accumulated)
        // This represents what the user would pay for a full period at this tier
        subscription.paidAmount = newTierPrice;
        subscription.totalSpent += msg.value;

        // Process payment and rewards (statistics updated inside)
        _processPayment(msg.sender, msg.value);

        // Record operation
        _recordOperation(
            msg.sender,
            DataTypes.OperationType.UPGRADE,
            oldTier,
            newTier,
            oldPeriod,
            newPeriod,
            msg.value,
            subscription.endTime
        );

        emit Upgraded(
            msg.sender,
            oldTier,
            newTier,
            msg.value,
            subscription.endTime
        );
    }

    /**
     * @notice Downgrade subscription to lower tier
     * @dev Can only be called after current subscription expires
     * @param newTier New subscription tier (must be lower than current)
     * @param period Payment period for the downgraded plan
     */
    function downgrade(
        DataTypes.SubscriptionTier newTier,
        DataTypes.SubscriptionPeriod period
    )
        external
        payable
        whenInitialized
        validTier(newTier)
        validPeriod(period)
        nonReentrant
    {
        DataTypes.UserSubscription storage subscription = userSubscriptions[
            msg.sender
        ];

        _requireSubscriptionExists(msg.sender);
        _requireExpiredSubscription(msg.sender);

        // Validate downgrade
        if (newTier >= subscription.tier) revert CannotDowngradeToSameTier();

        uint256 price = _getPrice(newTier, period);
        _validatePayment(price);

        // Update subscription
        DataTypes.SubscriptionTier oldTier = subscription.tier;
        DataTypes.SubscriptionPeriod oldPeriod = subscription.period;
        subscription.tier = newTier;
        subscription.period = period;
        subscription.startTime = block.timestamp;
        subscription.endTime = block.timestamp + _getDuration(period);
        subscription.paidAmount = msg.value;
        subscription.totalSpent += msg.value;

        // Process payment and rewards (statistics updated inside)
        _processPayment(msg.sender, msg.value);

        // Record operation
        _recordOperation(
            msg.sender,
            DataTypes.OperationType.DOWNGRADE,
            oldTier,
            newTier,
            oldPeriod,
            period,
            msg.value,
            subscription.endTime
        );

        emit Downgraded(
            msg.sender,
            oldTier,
            newTier,
            period,
            msg.value,
            subscription.endTime
        );
    }

    // ==================== Referral Functions ====================

    /**
     * @notice Claim accumulated referral rewards
     * @dev Can only claim once every 7 days
     */
    function claimReferralRewards() external nonReentrant {
        DataTypes.ReferralAccount storage account = referralAccounts[
            msg.sender
        ];

        // Check if there are rewards to claim
        if (account.pendingRewards == 0) {
            revert NoRewardsToClaim();
        }

        // Check cooldown period
        if (account.lastClaimTime + CLAIM_COOLDOWN > block.timestamp) {
            revert ClaimCooldownNotMet();
        }

        uint256 rewardAmount = account.pendingRewards;
        account.pendingRewards = 0;
        account.lastClaimTime = block.timestamp;

        // Update total pending rewards
        totalPendingReferralRewards -= rewardAmount;

        // Transfer rewards
        (bool success, ) = payable(msg.sender).call{value: rewardAmount}("");
        if (!success) revert TransferFailed();

        emit ReferralRewardsClaimed(msg.sender, rewardAmount);
    }

    // ==================== Reader Implementation Setup ====================
    
    /**
     * @notice Set the reader implementation contract
     * @param _readerImplementation Address of the reader contract
     */
    function setReaderImplementation(address _readerImplementation) external onlyOwner {
        readerImplementation = _readerImplementation;
    }

    // View functions removed - delegated to reader implementation via fallback

    // ==================== Internal Functions ====================

    function _getPrice(
        DataTypes.SubscriptionTier tier,
        DataTypes.SubscriptionPeriod period
    ) private view returns (uint256) {
        DataTypes.SubscriptionPlan storage plan = plans[tier];
        uint256 periodIndex = uint256(period);
        require(plan.enabled, "Tier not enabled");
        require(brandConfig.enabledPeriods[periodIndex], "Period not enabled");
        uint256 price = plan.prices[periodIndex];
        require(price > 0, "Price not set for this period");
        return price;
    }

    function _getDuration(
        DataTypes.SubscriptionPeriod period
    ) private pure returns (uint256) {
        if (period == DataTypes.SubscriptionPeriod.DAILY) return 1 days;
        if (period == DataTypes.SubscriptionPeriod.WEEKLY) return 7 days;
        if (period == DataTypes.SubscriptionPeriod.MONTHLY) return 30 days;
        return 365 days; // YEARLY
    }

    function _validatePayment(uint256 expectedAmount) private view {
        if (msg.value != expectedAmount) {
            if (msg.value < expectedAmount) revert InsufficientPayment();
            if (msg.value > (expectedAmount * 12) / 10) revert ExcessPayment();
        }
    }

    function _processPayment(
        address subscriber,
        uint256 paymentAmount
    ) private {
        // Cache storage reads
        DataTypes.UserSubscription storage subscription = userSubscriptions[
            subscriber
        ];
        address referrer = subscription.referrer;

        // Calculate fees
        uint256 platformFee = IFactory(factory).calculatePlatformFee(
            paymentAmount
        );
        uint256 cashback;
        uint256 referrerReward;
        bool hasValidReferrer;

        if (referrer != address(0)) {
            uint256 referrerEndTime = userSubscriptions[referrer].endTime;
            hasValidReferrer = referrerEndTime > block.timestamp;
            if (hasValidReferrer) {
                // Both cashback and referrer reward are 10% each
                cashback = (paymentAmount * REFERRAL_REWARD_RATE) / 10000;
                referrerReward = (paymentAmount * REFERRAL_REWARD_RATE) / 10000;
            }
        }

        // Validate funds
        uint256 totalOutflow = platformFee + cashback;
        require(totalOutflow <= paymentAmount, "Insufficient funds");

        // Update statistics BEFORE transfers
        totalGrossRevenue += paymentAmount;
        totalPlatformFeesPaid += platformFee;

        if (hasValidReferrer) {
            totalCashbackPaid += cashback;
            totalValidReferralRevenue += paymentAmount;
            // Note: totalReferralRewardsDistributed is updated in _processReferralRewards
        }

        // Calculate net revenue (what actually stays in the contract for project owner)
        // Must deduct: platform fee, cashback to subscriber, and referrer rewards
        uint256 netAmount = paymentAmount -
            platformFee -
            cashback -
            referrerReward;
        totalNetRevenue += netAmount;

        // Execute transfers
        if (platformFee > 0) {
            _safeTransfer(factory, platformFee);
        }

        if (hasValidReferrer) {
            _processReferralRewards(referrer, subscriber, paymentAmount);
            if (cashback > 0) {
                _safeTransfer(subscriber, cashback);
            }
        }
    }

    function _safeTransfer(address to, uint256 amount) private {
        (bool success, ) = payable(to).call{value: amount}("");
        if (!success) revert TransferFailed();
    }

    function _requireExpiredSubscription(address user) private view {
        if (userSubscriptions[user].endTime > block.timestamp) {
            revert SubscriptionStillActive();
        }
    }

    function _requireActiveSubscription(address user) private view {
        if (userSubscriptions[user].endTime <= block.timestamp) {
            revert NoActiveSubscription();
        }
    }

    function _requireSubscriptionExists(address user) private view {
        if (userSubscriptions[user].user == address(0)) {
            revert NoActiveSubscription();
        }
    }

    function _recordOperation(
        address user,
        DataTypes.OperationType opType,
        DataTypes.SubscriptionTier fromTier,
        DataTypes.SubscriptionTier toTier,
        DataTypes.SubscriptionPeriod fromPeriod,
        DataTypes.SubscriptionPeriod toPeriod,
        uint256 amount,
        uint256 newEndTime
    ) private {
        DataTypes.OperationRecord memory record = DataTypes.OperationRecord({
            user: user,
            operationType: opType,
            fromTier: fromTier,
            toTier: toTier,
            fromPeriod: fromPeriod,
            toPeriod: toPeriod,
            amount: amount,
            timestamp: block.timestamp,
            newEndTime: newEndTime
        });

        uint256 operationIndex = operationHistory.length;
        operationHistory.push(record);
        userOperationIndices[user].push(operationIndex);
    }

    function _processReferralRewards(
        address referrer,
        address subscriber,
        uint256 paymentAmount
    ) private {
        // Calculate 10% rewards
        uint256 rewardAmount = (paymentAmount * REFERRAL_REWARD_RATE) / 10000;

        // Update referrer's account (referrer gets 10% reward to claim later)
        DataTypes.ReferralAccount storage referrerAccount = referralAccounts[
            referrer
        ];
        referrerAccount.pendingRewards += rewardAmount;
        referrerAccount.totalRewards += rewardAmount;

        // Track total pending rewards
        totalPendingReferralRewards += rewardAmount;

        // Only count as new referral on first subscription
        if (
            userSubscriptions[subscriber].referrer == referrer &&
            userSubscriptions[subscriber].startTime == block.timestamp
        ) {
            referrerAccount.referralCount++;
            totalReferralSubscriptions++;
        }

        // Update subscriber's cashback tracking (separate from referrer rewards)
        DataTypes.UserSubscription storage subscription = userSubscriptions[
            subscriber
        ];
        subscription.totalRewardsEarned += rewardAmount;

        // Track only referrer rewards in totalReferralRewardsDistributed
        totalReferralRewardsDistributed += rewardAmount;

        emit ReferralRewardAccrued(
            referrer,
            subscriber,
            rewardAmount,
            rewardAmount
        );
    }

    // ==================== Proxy for View Functions ====================
    
    /**
     * @dev Fallback function to delegate view calls to reader implementation
     * @notice Uses delegatecall to allow reader to access this contract's storage
     * Security: Only the owner can set readerImplementation, and it should only contain view functions
     * The reader contract MUST NOT contain any state-modifying functions
     */
    fallback() external payable {
        address impl = readerImplementation;
        if (impl == address(0)) revert();
        
        assembly {
            calldatacopy(0, 0, calldatasize())
            // delegatecall allows the reader to access this contract's storage
            // This is necessary for view functions to read the state
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
    
    // Disabled functions
    function requestOwnershipHandover() public payable override {
        revert("This function is disabled");
    }

    function cancelOwnershipHandover() public payable override {
        revert("This function is disabled");
    }

    function completeOwnershipHandover(
        address /* pendingOwner */
    ) public payable override onlyOwner {
        revert("This function is disabled");
    }

    function ownershipHandoverExpiresAt(
        address /* pendingOwner */
    ) public view override returns (uint256 result) {
        result = brandConfig.maxTier;
        revert("This function is disabled");
    }

    function renounceOwnership() public payable override onlyOwner {
        revert("This function is disabled");
    }

    // ==================== Receive Function ====================
    receive() external payable {}
}
