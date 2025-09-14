// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "solady/auth/Ownable.sol";
import {DataTypes} from "./DataTypes.sol";

contract ProjectStorage is Ownable {
    // ========== Basic Configuration ==========
    DataTypes.BrandConfig public brandConfig;
    address public factory;
    bool public initialized;

    // State Variables (public for reader access)
    mapping(address => DataTypes.UserSubscription) public userSubscriptions;
    mapping(DataTypes.SubscriptionTier => DataTypes.SubscriptionPlan) public plans;

    // ========== Referral Rewards Storage ==========
    mapping(address => DataTypes.ReferralAccount) public referralAccounts; // Referral account data
    uint256 public totalReferralSubscriptions; // Total referral subscriptions
    uint256 public totalReferralRewardsDistributed; // Total referral rewards distributed
    uint256 public totalPendingReferralRewards; // Total unclaimed referral rewards
    uint256 public constant REFERRAL_REWARD_RATE = 1000; // 10% in basis points (1000/10000)
    uint256 public constant CLAIM_COOLDOWN = 7 days; // 7-day claim cooldown

    // ========== Statistics Storage ==========
    uint256 public totalGrossRevenue; // Total gross revenue (before fees)
    uint256 public totalNetRevenue; // Total net revenue (after all fees and cashback)
    uint256 public totalPlatformFeesPaid; // Total platform fees paid to factory
    uint256 public totalCashbackPaid; // Total cashback paid to subscribers
    uint256 public totalSubscribers; // Total number of subscribers
    uint256 public totalReferrers; // Total number of unique referrers who earned rewards
    uint256 public totalValidReferralRevenue; // Total revenue from subscriptions with valid referrers

    // ========== List Storage for Pagination ==========
    address[] public subscribersList; // List of all subscribers
    mapping(address => address[]) public referrerToUsers; // Referrer => list of referred users

    // ========== Operation History Storage ==========
    DataTypes.OperationRecord[] public operationHistory; // All operations
    mapping(address => uint256[]) public userOperationIndices; // User => list of operation indices
}
