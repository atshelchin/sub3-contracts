// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {DataTypes} from "./DataTypes.sol";
import {ProjectStorage} from "./ProjectStorage.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {IFactory} from "./interfaces/IFactory.sol";
import {IProject} from "./interfaces/IProject.sol";

contract Project is IProject, ProjectStorage, ReentrancyGuard {
    // Events and Errors are defined in IProject interface

    // ==================== Modifiers ====================
    modifier whenInitialized() {
        if (!initialized) revert NotInitialized();
        _;
    }

    modifier validTier(DataTypes.SubscriptionTier tier) {
        if (uint256(tier) > uint256(DataTypes.SubscriptionTier.MAX)) {
            revert InvalidTier();
        }
        _;
    }

    modifier validPeriod(DataTypes.SubscriptionPeriod period) {
        if (uint256(period) > uint256(DataTypes.SubscriptionPeriod.YEARLY)) {
            revert InvalidPeriod();
        }
        _;
    }

    // ==================== Initialization ====================
    function initialize(DataTypes.BrandConfig memory _brandConfig, address _factory, address _owner) external {
        if (initialized) revert ProjectAlreadyInitialized();
        initialized = true;
        brandConfig = _brandConfig;
        factory = _factory;
        _initializeOwner(_owner);

        // Initialize default plans
        _initializeDefaultPlans();
    }

    function _initializeDefaultPlans() private {
        // PRO Plan
        plans[DataTypes.SubscriptionTier.PRO] = DataTypes.SubscriptionPlan({
            tier: DataTypes.SubscriptionTier.PRO,
            monthlyPrice: 0.01 ether,
            yearlyPrice: 0.1 ether, // ~17% discount
            features: new string[](0)
        });

        // MAX Plan
        plans[DataTypes.SubscriptionTier.MAX] = DataTypes.SubscriptionPlan({
            tier: DataTypes.SubscriptionTier.MAX,
            monthlyPrice: 0.03 ether,
            yearlyPrice: 0.3 ether, // ~17% discount
            features: new string[](0)
        });
    }

    // ==================== Admin Functions ====================

    /**
     * @notice Set subscription plan configuration
     * @dev Only owner can call this function to update pricing and features
     * @param tier Subscription tier to update
     * @param monthlyPrice Monthly subscription price in wei
     * @param yearlyPrice Yearly subscription price in wei
     * @param features Array of feature descriptions
     */
    function setPlanConfig(
        DataTypes.SubscriptionTier tier,
        uint256 monthlyPrice,
        uint256 yearlyPrice,
        string[] memory features
    ) external onlyOwner whenInitialized validTier(tier) {
        if (monthlyPrice == 0 || yearlyPrice == 0) revert InvalidPrice();

        plans[tier].monthlyPrice = monthlyPrice;
        plans[tier].yearlyPrice = yearlyPrice;
        plans[tier].features = features;

        emit PlanConfigUpdated(tier, monthlyPrice, yearlyPrice, features);
    }

    /**
     * @notice Update brand configuration (name and symbol cannot be changed)
     * @dev Only owner can update brand settings except name and symbol
     * @param newConfig New brand configuration
     */
    function updateBrandConfig(DataTypes.BrandConfig memory newConfig) external onlyOwner whenInitialized {
        // Name and symbol must remain the same
        require(keccak256(bytes(newConfig.name)) == keccak256(bytes(brandConfig.name)), "Name cannot be changed");
        require(keccak256(bytes(newConfig.symbol)) == keccak256(bytes(brandConfig.symbol)), "Symbol cannot be changed");

        // Update other fields
        brandConfig.description = newConfig.description;
        brandConfig.logoUri = newConfig.logoUri;
        brandConfig.websiteUrl = newConfig.websiteUrl;
        brandConfig.primaryColor = newConfig.primaryColor;

        emit BrandConfigUpdated(brandConfig.name, brandConfig.symbol);
    }

    /**
     * @notice Withdraw contract balance
     * @dev Only owner can call this function with reentrancy protection
     * @param to Recipient address
     * @param amount Amount to withdraw in wei
     */
    function withdraw(address to, uint256 amount) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (address(this).balance < amount) revert InsufficientBalance();

        _safeTransfer(to, amount);

        emit Withdrawn(to, amount);
    }

    // ==================== Subscription Functions ====================

    /**
     * @notice Subscribe to a service plan (first-time subscribers only)
     * @dev User must never have subscribed before, can optionally provide a referrer
     * @param tier Subscription tier (PRO or MAX)
     * @param period Payment period (MONTHLY or YEARLY)
     * @param referrer Optional referrer address (must have active subscription)
     */
    function subscribe(DataTypes.SubscriptionTier tier, DataTypes.SubscriptionPeriod period, address referrer)
        external
        payable
        whenInitialized
        validTier(tier)
        validPeriod(period)
        nonReentrant
    {
        // Check first-time subscriber
        if (userSubscriptions[msg.sender].user != address(0)) revert AlreadySubscribed();

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
            totalRewardsEarned: 0
        });

        // Update subscriber count
        totalSubscribers++;

        // Check if this creates a new referrer (only if valid)
        if (validReferrer != address(0)) {
            // Check if referrer is becoming active for the first time
            if (referralAccounts[validReferrer].referralCount == 0) {
                totalReferrers++;
            }
        }

        // Process payment and rewards
        _processPayment(msg.sender, msg.value);

        emit Subscribed(msg.sender, tier, period, msg.value, endTime);
    }

    /**
     * @notice Renew expired subscription with same tier
     * @dev Can only renew after subscription expires
     * @param period Payment period for renewal (MONTHLY or YEARLY)
     */
    function renew(DataTypes.SubscriptionPeriod period)
        external
        payable
        whenInitialized
        validPeriod(period)
        nonReentrant
    {
        DataTypes.UserSubscription storage subscription = userSubscriptions[msg.sender];

        _requireSubscriptionExists(msg.sender);
        _requireExpiredSubscription(msg.sender);

        uint256 price = _getPrice(subscription.tier, period);
        _validatePayment(price);

        // Update subscription
        subscription.startTime = block.timestamp;
        subscription.endTime = block.timestamp + _getDuration(period);
        subscription.period = period;
        subscription.paidAmount = msg.value;

        // Process payment and rewards (statistics updated inside)
        _processPayment(msg.sender, msg.value);

        emit Renewed(msg.sender, period, msg.value, subscription.endTime);
    }

    /**
     * @notice Upgrade subscription to higher tier
     * @dev Extends subscription by one period from current end date with upgraded tier
     * @param newTier New subscription tier (must be higher than current)
     */
    function upgrade(DataTypes.SubscriptionTier newTier)
        external
        payable
        whenInitialized
        validTier(newTier)
        nonReentrant
    {
        DataTypes.UserSubscription storage subscription = userSubscriptions[msg.sender];

        _requireActiveSubscription(msg.sender);

        // Validate upgrade
        if (subscription.tier == newTier) revert CannotUpgradeToSameTier();
        if (newTier < subscription.tier) revert InvalidTier();

        // Calculate upgrade cost safely
        uint256 remainingTime = subscription.endTime - block.timestamp;
        uint256 periodDuration = _getDuration(subscription.period);
        uint256 newTierPrice = _getPrice(newTier, subscription.period);
        uint256 currentTierPrice = _getPrice(subscription.tier, subscription.period);

        // Calculate costs separately to avoid underflow
        uint256 remainingNewCost = (newTierPrice * remainingTime) / periodDuration;
        uint256 fullPeriodCost = newTierPrice;
        uint256 remainingOldCredit = (currentTierPrice * remainingTime) / periodDuration;

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
        subscription.tier = newTier;
        subscription.endTime = subscription.endTime + periodDuration;
        subscription.paidAmount = subscription.paidAmount + msg.value;

        // Process payment and rewards (statistics updated inside)
        _processPayment(msg.sender, msg.value);

        emit Upgraded(msg.sender, oldTier, newTier, msg.value, subscription.endTime);
    }

    /**
     * @notice Downgrade subscription to lower tier
     * @dev Can only be called after current subscription expires
     * @param newTier New subscription tier (must be lower than current)
     * @param period Payment period for the downgraded plan
     */
    function downgrade(DataTypes.SubscriptionTier newTier, DataTypes.SubscriptionPeriod period)
        external
        payable
        whenInitialized
        validTier(newTier)
        validPeriod(period)
        nonReentrant
    {
        DataTypes.UserSubscription storage subscription = userSubscriptions[msg.sender];

        _requireSubscriptionExists(msg.sender);
        _requireExpiredSubscription(msg.sender);

        // Validate downgrade
        if (newTier >= subscription.tier) revert CannotDowngradeToSameTier();

        uint256 price = _getPrice(newTier, period);
        _validatePayment(price);

        // Update subscription
        DataTypes.SubscriptionTier oldTier = subscription.tier;
        subscription.tier = newTier;
        subscription.period = period;
        subscription.startTime = block.timestamp;
        subscription.endTime = block.timestamp + _getDuration(period);
        subscription.paidAmount = msg.value;

        // Process payment and rewards (statistics updated inside)
        _processPayment(msg.sender, msg.value);

        emit Downgraded(msg.sender, oldTier, newTier, period, msg.value, subscription.endTime);
    }

    // ==================== Referral Functions ====================

    /**
     * @notice Claim accumulated referral rewards
     * @dev Can only claim once every 7 days
     */
    function claimReferralRewards() external nonReentrant {
        DataTypes.ReferralAccount storage account = referralAccounts[msg.sender];

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

        // Transfer rewards
        (bool success,) = payable(msg.sender).call{value: rewardAmount}("");
        if (!success) revert TransferFailed();

        emit ReferralRewardsClaimed(msg.sender, rewardAmount);
    }

    // ==================== View Functions ====================

    /**
     * @notice Get subscription plan details
     * @param tier Subscription tier to query
     * @return plan Plan details including prices and features
     */
    function getPlan(DataTypes.SubscriptionTier tier)
        external
        view
        whenInitialized
        validTier(tier)
        returns (DataTypes.SubscriptionPlan memory plan)
    {
        return plans[tier];
    }

    /**
     * @notice Get all available subscription plans
     * @return allPlans Array of all subscription plans
     */
    function getAllPlans() external view whenInitialized returns (DataTypes.SubscriptionPlan[] memory allPlans) {
        allPlans = new DataTypes.SubscriptionPlan[](2);
        allPlans[0] = plans[DataTypes.SubscriptionTier.PRO];
        allPlans[1] = plans[DataTypes.SubscriptionTier.MAX];
        return allPlans;
    }

    /**
     * @notice Get user's subscription information
     * @param user User address to query
     * @return subscription User's subscription details
     */
    function getUserSubscription(address user)
        external
        view
        whenInitialized
        returns (DataTypes.UserSubscription memory subscription)
    {
        return userSubscriptions[user];
    }

    /**
     * @notice Check if user has active subscription
     * @param user User address to check
     * @return True if subscription is active, false otherwise
     */
    function hasActiveSubscription(address user) external view whenInitialized returns (bool) {
        return userSubscriptions[user].endTime > block.timestamp;
    }

    /**
     * @notice Get referral account information
     * @param referrer Referrer address to query
     * @return account Referral account details
     */
    function getReferralAccount(address referrer)
        external
        view
        whenInitialized
        returns (DataTypes.ReferralAccount memory)
    {
        return referralAccounts[referrer];
    }

    /**
     * @notice Get global referral statistics
     * @return totalSubscriptions Total number of referral subscriptions
     * @return totalRewards Total rewards distributed
     */
    function getReferralStats()
        external
        view
        whenInitialized
        returns (uint256 totalSubscriptions, uint256 totalRewards)
    {
        return (totalReferralSubscriptions, totalReferralRewardsDistributed);
    }

    /**
     * @notice Get user's total rewards earned
     * @param user User address to query
     * @return totalRewards Total rewards earned by the user
     */
    function getUserTotalRewards(address user) external view whenInitialized returns (uint256) {
        return userSubscriptions[user].totalRewardsEarned;
    }

    /**
     * @notice Get comprehensive project statistics
     * @dev Returns all key metrics for display
     * @return grossRevenue Total gross revenue (before any fees)
     * @return netRevenue Total net revenue (actual contract balance retained)
     * @return subscribers Total number of subscribers
     * @return referrers Total number of active referrers
     * @return validReferralRevenue Revenue from subscriptions with valid referrers
     * @return referralRewards Total referral rewards pending/claimed
     * @return platformFees Total platform fees paid
     * @return cashbackPaid Total cashback paid to subscribers
     */
    function getProjectStats()
        external
        view
        whenInitialized
        returns (
            uint256 grossRevenue,
            uint256 netRevenue,
            uint256 subscribers,
            uint256 referrers,
            uint256 validReferralRevenue,
            uint256 referralRewards,
            uint256 platformFees,
            uint256 cashbackPaid
        )
    {
        return (
            totalGrossRevenue,
            totalNetRevenue,
            totalSubscribers,
            totalReferrers,
            totalValidReferralRevenue,
            totalReferralRewardsDistributed,
            totalPlatformFeesPaid,
            totalCashbackPaid
        );
    }

    // ==================== Internal Functions ====================

    function _getPrice(DataTypes.SubscriptionTier tier, DataTypes.SubscriptionPeriod period)
        private
        view
        returns (uint256)
    {
        DataTypes.SubscriptionPlan storage plan = plans[tier];
        return period == DataTypes.SubscriptionPeriod.MONTHLY ? plan.monthlyPrice : plan.yearlyPrice;
    }

    function _getDuration(DataTypes.SubscriptionPeriod period) private pure returns (uint256) {
        return period == DataTypes.SubscriptionPeriod.MONTHLY ? 30 days : 365 days;
    }

    function _validatePayment(uint256 expectedAmount) private view {
        if (msg.value != expectedAmount) {
            if (msg.value < expectedAmount) revert InsufficientPayment();
            else revert ExcessPayment();
        }
    }

    function _processPayment(address subscriber, uint256 paymentAmount) private {
        // Cache storage reads
        DataTypes.UserSubscription storage subscription = userSubscriptions[subscriber];
        address referrer = subscription.referrer;

        // Calculate fees
        uint256 platformFee = IFactory(factory).calculatePlatformFee(paymentAmount);
        uint256 cashback;
        bool hasValidReferrer;

        if (referrer != address(0)) {
            uint256 referrerEndTime = userSubscriptions[referrer].endTime;
            hasValidReferrer = referrerEndTime > block.timestamp;
            if (hasValidReferrer) {
                cashback = (paymentAmount * REFERRAL_REWARD_RATE) / 10000;
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
        }

        // Calculate net revenue (what actually stays in the contract)
        uint256 netAmount = paymentAmount - platformFee - cashback;
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
        (bool success,) = payable(to).call{value: amount}("");
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

    function _processReferralRewards(address referrer, address subscriber, uint256 paymentAmount) private {
        // Calculate 10% rewards
        uint256 rewardAmount = (paymentAmount * REFERRAL_REWARD_RATE) / 10000;

        // Update referrer's account (referrer gets 10% reward to claim later)
        DataTypes.ReferralAccount storage referrerAccount = referralAccounts[referrer];
        referrerAccount.pendingRewards += rewardAmount;
        referrerAccount.totalRewards += rewardAmount;

        // Only count as new referral on first subscription
        if (
            userSubscriptions[subscriber].referrer == referrer
                && userSubscriptions[subscriber].startTime == block.timestamp
        ) {
            referrerAccount.referralCount++;
            totalReferralSubscriptions++;
        }

        // Update subscriber's cashback tracking (separate from referrer rewards)
        DataTypes.UserSubscription storage subscription = userSubscriptions[subscriber];
        subscription.totalRewardsEarned += rewardAmount;

        // Track only referrer rewards in totalReferralRewardsDistributed
        totalReferralRewardsDistributed += rewardAmount;

        emit ReferralRewardAccrued(referrer, subscriber, rewardAmount, rewardAmount);
    }

    // ==================== Receive Function ====================
    receive() external payable {}
}
