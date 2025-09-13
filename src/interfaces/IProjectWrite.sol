// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {DataTypes} from "../DataTypes.sol";

/**
 * @title IProjectWrite
 * @notice Interface for write functions of the Project contract
 */
interface IProjectWrite {
    // ==================== Events ====================
    event PlanConfigUpdated(
        DataTypes.SubscriptionTier tier,
        uint256[4] prices,
        string customName,
        string[] features
    );
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
        address indexed referrer,
        address indexed subscriber,
        uint256 referrerReward,
        uint256 subscriberReward
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
    function setPlanConfig(
        DataTypes.SubscriptionTier tier,
        uint256[4] memory prices,
        string[] memory features
    ) external;

    function updateBrandConfig(DataTypes.BrandConfig memory newConfig) external;

    function withdraw(address to) external;
    
    function setReaderImplementation(address _readerImplementation) external;

    // ==================== Subscription Functions ====================
    function subscribe(
        DataTypes.SubscriptionTier tier,
        DataTypes.SubscriptionPeriod period,
        address referrer
    ) external payable;

    function renew(
        DataTypes.SubscriptionTier tier,
        DataTypes.SubscriptionPeriod period
    ) external payable;

    function upgrade(
        DataTypes.SubscriptionTier newTier,
        DataTypes.SubscriptionPeriod newPeriod
    ) external payable;

    function downgrade(
        DataTypes.SubscriptionTier newTier,
        DataTypes.SubscriptionPeriod period
    ) external payable;

    // ==================== Referral Functions ====================
    function claimReferralRewards() external;
}