// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {DataTypes} from "./DataTypes.sol";
import {ProjectStorage} from "./ProjectStorage.sol";
import {IProjectRead} from "./interfaces/IProjectRead.sol";

/**
 * @title ProjectReaderImpl
 * @notice Implementation contract for all view functions
 * @dev This contract is called via delegatecall from Project
 */
contract ProjectReaderImpl is IProjectRead, ProjectStorage {
    // ==================== View Functions ====================
    function getBrandConfig() external view returns (DataTypes.BrandConfig memory) {
        return brandConfig;
    }
    
    function getEnabledPeriods() external view returns (bool[4] memory) {
        return brandConfig.enabledPeriods;
    }
    
    function getTierNames() external view returns (string[4] memory) {
        return brandConfig.tierNames;
    }
    
    function getPlan(DataTypes.SubscriptionTier tier) 
        external view returns (DataTypes.SubscriptionPlan memory) {
        return plans[tier];
    }
    
    function getAllPlans() external view returns (DataTypes.SubscriptionPlan[] memory allPlans) {
        allPlans = new DataTypes.SubscriptionPlan[](uint256(brandConfig.maxTier) + 1);
        for (uint8 i = 0; i <= brandConfig.maxTier; i++) {
            allPlans[i] = plans[DataTypes.SubscriptionTier(i)];
        }
    }
    
    function getUserSubscription(address user) 
        external view returns (DataTypes.UserSubscription memory) {
        return userSubscriptions[user];
    }
    
    function hasActiveSubscription(address user) external view returns (bool) {
        return userSubscriptions[user].endTime > block.timestamp;
    }
    
    function getReferralAccount(address referrer) 
        external view returns (DataTypes.ReferralAccount memory) {
        return referralAccounts[referrer];
    }
    
    function getReferralStats() external view returns (
        uint256 totalSubscriptions,
        uint256 totalRewards,
        uint256 pendingRewards
    ) {
        return (
            totalReferralSubscriptions,
            totalReferralRewardsDistributed,
            totalPendingReferralRewards
        );
    }
    
    function getUserTotalRewards(address user) external view returns (uint256) {
        return userSubscriptions[user].totalRewardsEarned;
    }
    
    function getProjectStats() external view returns (
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
    ) {
        return (
            totalGrossRevenue,
            totalNetRevenue,
            totalSubscribers,
            totalReferrers,
            totalValidReferralRevenue,
            totalReferralRewardsDistributed,
            totalPendingReferralRewards,
            totalReferralSubscriptions,
            totalPlatformFeesPaid,
            totalCashbackPaid
        );
    }
    
    function getWithdrawableBalance() external view returns (
        uint256 withdrawableAmount,
        uint256 totalBalance,
        uint256 reservedForReferrals
    ) {
        totalBalance = address(this).balance;
        reservedForReferrals = totalPendingReferralRewards;
        withdrawableAmount = totalBalance > reservedForReferrals
            ? totalBalance - reservedForReferrals
            : 0;
    }
    
    function getSubscribersPaginated(uint256 offset, uint256 limit)
        external view returns (
            address[] memory subscribers,
            DataTypes.UserSubscription[] memory subscriptions,
            uint256 total
        )
    {
        total = subscribersList.length;
        
        if (offset >= total) {
            return (
                new address[](0),
                new DataTypes.UserSubscription[](0),
                total
            );
        }
        
        if (limit > 100) {
            limit = 100;
        }
        
        uint256 remaining = total - offset;
        uint256 returnCount = remaining < limit ? remaining : limit;
        
        subscribers = new address[](returnCount);
        subscriptions = new DataTypes.UserSubscription[](returnCount);
        
        for (uint256 i = 0; i < returnCount; i++) {
            address subscriber = subscribersList[offset + i];
            subscribers[i] = subscriber;
            subscriptions[i] = userSubscriptions[subscriber];
        }
    }
    
    function getReferralsPaginated(address referrer, uint256 offset, uint256 limit)
        external view returns (address[] memory referredUsers, uint256 total)
    {
        address[] storage referrals = referrerToUsers[referrer];
        total = referrals.length;
        
        if (offset >= total) {
            return (new address[](0), total);
        }
        
        if (limit > 100) {
            limit = 100;
        }
        
        uint256 remaining = total - offset;
        uint256 returnCount = remaining < limit ? remaining : limit;
        
        referredUsers = new address[](returnCount);
        
        for (uint256 i = 0; i < returnCount; i++) {
            referredUsers[i] = referrals[offset + i];
        }
    }
    
    function getOperationHistoryPaginated(uint256 offset, uint256 limit)
        external view returns (DataTypes.OperationRecord[] memory records, uint256 total)
    {
        total = operationHistory.length;
        
        if (offset >= total) {
            return (new DataTypes.OperationRecord[](0), total);
        }
        
        if (limit > 100) {
            limit = 100;
        }
        
        uint256 remaining = total - offset;
        uint256 returnCount = remaining < limit ? remaining : limit;
        
        records = new DataTypes.OperationRecord[](returnCount);
        
        for (uint256 i = 0; i < returnCount; i++) {
            records[i] = operationHistory[offset + i];
        }
    }
    
    function getUserOperationHistoryPaginated(address user, uint256 offset, uint256 limit)
        external view returns (DataTypes.OperationRecord[] memory records, uint256 total)
    {
        uint256[] storage userOps = userOperationIndices[user];
        total = userOps.length;
        
        if (offset >= total) {
            return (new DataTypes.OperationRecord[](0), total);
        }
        
        if (limit > 100) {
            limit = 100;
        }
        
        uint256 remaining = total - offset;
        uint256 returnCount = remaining < limit ? remaining : limit;
        
        records = new DataTypes.OperationRecord[](returnCount);
        
        for (uint256 i = 0; i < returnCount; i++) {
            uint256 operationIndex = userOps[offset + i];
            records[i] = operationHistory[operationIndex];
        }
    }
}