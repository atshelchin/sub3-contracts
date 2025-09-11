// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {Ownable} from "solady/auth/Ownable.sol";
import {DataTypes} from "./DataTypes.sol";

contract ProjectStorage is Ownable {
    // ========== Basic Configuration ==========
    DataTypes.BrandConfig public brandConfig;
    address public factory;
    bool public initialized;

    // State Variables
    mapping(address => DataTypes.UserSubscription) internal userSubscriptions;
    mapping(DataTypes.SubscriptionTier => DataTypes.SubscriptionPlan)
        internal plans;

    // ========== Referral Rewards Storage ==========
    mapping(address => DataTypes.ReferralAccount) public referralAccounts; // Referral account data
    uint256 public totalReferralSubscriptions; // Total referral subscriptions
    uint256 public totalReferralRewardsDistributed; // Total referral rewards distributed
    uint256 public constant REFERRAL_REWARD_RATE = 1000; // 10% in basis points (1000/10000)
    uint256 public constant CLAIM_COOLDOWN = 7 days; // 7-day claim cooldown
}
