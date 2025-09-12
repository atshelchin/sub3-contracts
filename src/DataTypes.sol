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
        uint8 maxTier; // Maximum tier enabled (0-3)
        bool[4] enabledPeriods; // Which periods are enabled [daily, weekly, monthly, yearly]
    }

    struct ReferralAccount {
        uint256 pendingRewards; // Pending referral rewards
        uint256 totalRewards; // Total referral rewards earned
        uint256 lastClaimTime; // Last claim timestamp
        uint256 referralCount; // Number of successful referrals
    }

    enum SubscriptionTier {
        STARTER,  // 0: Starter plan
        STANDARD, // 1: Standard plan
        PRO,      // 2: Pro plan
        MAX       // 3: Max plan
    }

    enum SubscriptionPeriod {
        DAILY,   // 0: Daily payment
        WEEKLY,  // 1: Weekly payment
        MONTHLY, // 2: Monthly payment
        YEARLY   // 3: Yearly payment
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
        bool enabled; // Whether this tier is enabled
        string customName; // Custom name for the tier
        uint256[4] prices; // Prices for [daily, weekly, monthly, yearly] - 0 means period not available
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
