// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title DataTypes
 * @notice Data structure definitions
 */
library DataTypes {
    struct BrandConfig {
        string name; // Name
        string symbol; // Symbol
        string description; // Description
        string logoUri; // Logo URI
        string websiteUrl; // Website URL
        string primaryColor; // Primary color
    }

    struct ReferralAccount {
        uint256 pendingRewards; // Pending referral rewards
        uint256 totalRewards; // Total referral rewards earned
        uint256 lastClaimTime; // Last claim timestamp
        uint256 referralCount; // Number of successful referrals
    }

    enum SubscriptionTier {
        PRO, // 0: Pro plan
        MAX // 1: Max plan
    }

    enum SubscriptionPeriod {
        MONTHLY, // 0: Monthly payment
        YEARLY // 1: Yearly payment
    }

    enum SubscriptionStatus {
        ACTIVE, // 0: Active
        EXPIRED // 1: Expired
    }

    enum OperationType {
        SUBSCRIBE, // 0: Subscribe
        UPGRADE, // 1: Upgrade
        DOWNGRADE, // 2: Downgrade
        RENEW // 3: Renew
    }
    struct SubscriptionPlan {
        SubscriptionTier tier; // Subscription tier
        uint256 monthlyPrice; // Monthly price (wei)
        uint256 yearlyPrice; // Yearly price (wei)
        string[] features; // Feature list
    }
    struct UserSubscription {
        address user; // User address
        address referrer; // Referrer address
        SubscriptionTier tier; // Current tier
        SubscriptionPeriod period; // Payment period
        uint256 startTime; // Start timestamp
        uint256 endTime; // End timestamp
        uint256 paidAmount; // Amount paid
        uint256 totalRewardsEarned; // Total rewards earned by user
    }
}
