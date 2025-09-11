// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {DataTypes} from "../DataTypes.sol";

/**
 * @title IProject
 * @notice Interface for the Project subscription contract
 */
interface IProject {
    // ==================== Events ====================
    event PlanConfigUpdated(
        DataTypes.SubscriptionTier tier, uint256 monthlyPrice, uint256 yearlyPrice, string[] features
    );
    event Subscribed(
        address indexed user,
        DataTypes.SubscriptionTier tier,
        DataTypes.SubscriptionPeriod period,
        uint256 amount,
        uint256 endTime
    );
    event Renewed(address indexed user, DataTypes.SubscriptionPeriod period, uint256 amount, uint256 newEndTime);
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
    function initialize(DataTypes.BrandConfig memory _brandConfig, address _factory, address _owner) external;

    // ==================== Admin Functions ====================
    function setPlanConfig(
        DataTypes.SubscriptionTier tier,
        uint256 monthlyPrice,
        uint256 yearlyPrice,
        string[] memory features
    ) external;

    function updateBrandConfig(DataTypes.BrandConfig memory newConfig) external;

    function withdraw(address to, uint256 amount) external;

    // ==================== Subscription Functions ====================
    function subscribe(DataTypes.SubscriptionTier tier, DataTypes.SubscriptionPeriod period, address referrer)
        external
        payable;

    function renew(DataTypes.SubscriptionPeriod period) external payable;

    function upgrade(DataTypes.SubscriptionTier newTier) external payable;

    function downgrade(DataTypes.SubscriptionTier newTier, DataTypes.SubscriptionPeriod period) external payable;

    // ==================== Referral Functions ====================
    function claimReferralRewards() external;

    // ==================== View Functions ====================
    function getPlan(DataTypes.SubscriptionTier tier) external view returns (DataTypes.SubscriptionPlan memory plan);

    function getAllPlans() external view returns (DataTypes.SubscriptionPlan[] memory allPlans);

    function getUserSubscription(address user) external view returns (DataTypes.UserSubscription memory subscription);

    function hasActiveSubscription(address user) external view returns (bool);

    function getReferralAccount(address referrer) external view returns (DataTypes.ReferralAccount memory);

    function getReferralStats() external view returns (uint256 totalSubscriptions, uint256 totalRewards);

    function getUserTotalRewards(address user) external view returns (uint256);

    function getProjectStats()
        external
        view
        returns (
            uint256 grossRevenue,
            uint256 netRevenue,
            uint256 subscribers,
            uint256 referrers,
            uint256 validReferralRevenue,
            uint256 referralRewards,
            uint256 platformFees,
            uint256 cashbackPaid
        );
}
