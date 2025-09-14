// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {DataTypes} from "../DataTypes.sol";

/**
 * @title IProjectRead
 * @notice Interface for read/view functions of the Project contract
 */
interface IProjectRead {
    // ==================== View Functions ====================

    function getBrandConfig() external view returns (DataTypes.BrandConfig memory);

    function getEnabledPeriods() external view returns (bool[4] memory);

    function getTierNames() external view returns (string[4] memory);

    function getPlan(DataTypes.SubscriptionTier tier) external view returns (DataTypes.SubscriptionPlan memory);

    function getAllPlans() external view returns (DataTypes.SubscriptionPlan[] memory);

    function getUserSubscription(address user) external view returns (DataTypes.UserSubscription memory);

    function hasActiveSubscription(address user) external view returns (bool);

    function getReferralAccount(address referrer) external view returns (DataTypes.ReferralAccount memory);

    function getReferralStats()
        external
        view
        returns (uint256 totalSubscriptions, uint256 totalRewards, uint256 pendingRewards);

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

    function getSubscribersPaginated(uint256 offset, uint256 limit)
        external
        view
        returns (address[] memory subscribers, DataTypes.UserSubscription[] memory subscriptions, uint256 total);

    function getReferralsPaginated(address referrer, uint256 offset, uint256 limit)
        external
        view
        returns (address[] memory referredUsers, uint256 total);

    function getOperationHistoryPaginated(uint256 offset, uint256 limit)
        external
        view
        returns (DataTypes.OperationRecord[] memory records, uint256 total);

    function getUserOperationHistoryPaginated(address user, uint256 offset, uint256 limit)
        external
        view
        returns (DataTypes.OperationRecord[] memory records, uint256 total);
}
