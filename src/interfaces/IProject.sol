// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {DataTypes} from "../DataTypes.sol";

/**
 * @title IProject
 * @notice Interface for the Project subscription contract
 */
interface IProject {
    // ==================== Events ====================
    event PlanConfigUpdated(DataTypes.SubscriptionTier tier, uint256[4] prices, string customName, string[] features);
    event Subscribed(
        address indexed user,
        DataTypes.SubscriptionTier tier,
        DataTypes.SubscriptionPeriod period,
        uint256 amount,
        uint256 endTime
    );
    event Renewed(
        address indexed user,
        DataTypes.SubscriptionTier tier,
        DataTypes.SubscriptionPeriod period,
        uint256 amount,
        uint256 newEndTime
    );
    event Upgraded(
        address indexed user,
        DataTypes.SubscriptionTier fromTier,
        DataTypes.SubscriptionTier toTier,
        uint256 amount,
        uint256 newEndTime
    );
    event Downgraded(
        address indexed user,
        DataTypes.SubscriptionTier fromTier,
        DataTypes.SubscriptionTier toTier,
        DataTypes.SubscriptionPeriod period,
        uint256 amount,
        uint256 endTime
    );
    event Withdrawn(address indexed to, uint256 amount);
    event BrandConfigUpdated(string name, string symbol);
    event ReferralRewardAccrued(
        address indexed referrer, address indexed subscriber, uint256 referrerReward, uint256 subscriberReward
    );
    event ReferralRewardsClaimed(address indexed referrer, uint256 amount);

    // ==================== Errors ====================
    error ProjectAlreadyInitialized();
    error NotInitialized();
    error InvalidTier();
    error InvalidPeriod();
    error InvalidPrice();
    error InsufficientPayment();
    error ExcessPayment();
    error NoActiveSubscription();
    error SubscriptionStillActive();
    error AlreadySubscribed();
    error CannotDowngradeToSameTier();
    error CannotUpgradeToSameTier();
    error InsufficientBalance();
    error TransferFailed();
    error ZeroAddress();
    error ZeroAmount();
    error NoRewardsToClaim();
    error ClaimCooldownNotMet();

    // ==================== Initialization ====================
    function initialize(
        DataTypes.BrandConfig memory _brandConfig,
        address _factory,
        address _owner,
        uint256[4][4] memory prices
    ) external;

    // ==================== Admin Functions ====================
    function setPlanConfig(DataTypes.SubscriptionTier tier, uint256[4] memory prices, string[] memory features)
        external;

    function updateBrandConfig(DataTypes.BrandConfig memory newConfig) external;

    function withdraw(address to) external;

    // ==================== Subscription Functions ====================
    function subscribe(DataTypes.SubscriptionTier tier, DataTypes.SubscriptionPeriod period, address referrer)
        external
        payable;

    function renew(DataTypes.SubscriptionTier tier, DataTypes.SubscriptionPeriod period) external payable;

    function upgrade(DataTypes.SubscriptionTier newTier, DataTypes.SubscriptionPeriod newPeriod) external payable;

    function downgrade(DataTypes.SubscriptionTier newTier, DataTypes.SubscriptionPeriod period) external payable;

    // ==================== Referral Functions ====================
    function claimReferralRewards() external;

    // ==================== View Functions ====================

    // Brand configuration getters (needed because public struct with arrays doesn't return arrays)
    function getBrandConfig() external view returns (DataTypes.BrandConfig memory);

    function getEnabledPeriods() external view returns (bool[4] memory);

    function getTierNames() external view returns (string[4] memory);

    // Plan and subscription getters
    function getPlan(DataTypes.SubscriptionTier tier) external view returns (DataTypes.SubscriptionPlan memory plan);

    function getAllPlans() external view returns (DataTypes.SubscriptionPlan[] memory allPlans);

    function getUserSubscription(address user) external view returns (DataTypes.UserSubscription memory subscription);

    function hasActiveSubscription(address user) external view returns (bool);

    function getReferralAccount(address referrer) external view returns (DataTypes.ReferralAccount memory);

    function getReferralStats()
        external
        view
        returns (uint256 totalSubscriptions, uint256 totalRewards, uint256 pendingRewards);

    function getUserTotalRewards(address user) external view returns (uint256);

    function getSubscribersPaginated(uint256 offset, uint256 limit)
        external
        view
        returns (address[] memory subscribers, DataTypes.UserSubscription[] memory subscriptions, uint256 total);

    function getReferralsPaginated(address referrer, uint256 offset, uint256 limit)
        external
        view
        returns (address[] memory referredUsers, uint256 total);

    function getProjectStats()
        external
        view
        returns (
            uint256 grossRevenue,
            uint256 netRevenue,
            uint256 subscribers,
            uint256 referrers,
            uint256 validReferralRevenue,
            uint256 referralRewardsDistributed,
            uint256 pendingReferralRewards,
            uint256 referralSubscriptions,
            uint256 platformFees,
            uint256 cashbackPaid
        );

    function getWithdrawableBalance()
        external
        view
        returns (uint256 withdrawableAmount, uint256 totalBalance, uint256 reservedForReferrals);

    function getOperationHistoryPaginated(uint256 offset, uint256 limit)
        external
        view
        returns (DataTypes.OperationRecord[] memory records, uint256 total);

    function getUserOperationHistoryPaginated(address user, uint256 offset, uint256 limit)
        external
        view
        returns (DataTypes.OperationRecord[] memory records, uint256 total);
}
