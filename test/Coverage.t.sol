// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Factory.sol";
import {Project} from "../src/Project.sol";
import "../src/DataTypes.sol";

/**
 * @title Coverage Tests
 * @notice Additional tests to ensure 100% function coverage
 */
contract CoverageTest is Test {
    Factory public factory;
    Project public projectImpl;
    Project public project;

    address public factoryOwner = address(0x1);
    address public projectOwner = address(0x2);
    address public newOwner = address(0x3);
    address public subscriber = address(0x4);

    uint256 constant PROJECT_CREATION_FEE = 0.01 ether;
    uint256 constant PRO_MONTHLY = 0.01 ether;

    function setUp() public {
        // Deploy factory
        vm.startPrank(factoryOwner);
        projectImpl = new Project();
        factory = new Factory(factoryOwner, address(projectImpl));
        vm.stopPrank();

        // Deploy a project for testing
        DataTypes.BrandConfig memory brandConfig = DataTypes.BrandConfig({
            name: "TestProject",
            symbol: "TP",
            description: "Test Description",
            logoUri: "https://logo.com",
            websiteUrl: "https://website.com",
            primaryColor: "#000000",
            maxTier: uint8(DataTypes.SubscriptionTier.MAX),
            enabledPeriods: [false, false, true, true],
            tierNames: ["Starter", "Standard", "Pro", "Max"]
        });

        uint256[4][4] memory prices;
        prices[0] = [uint256(0), 0, 0.005 ether, 0.05 ether];
        prices[1] = [uint256(0), 0, 0.007 ether, 0.07 ether];
        prices[2] = [uint256(0), 0, PRO_MONTHLY, 0.1 ether];
        prices[3] = [uint256(0), 0, 0.02 ether, 0.2 ether];

        vm.deal(projectOwner, 1 ether);
        vm.prank(projectOwner);
        address projectAddr = factory.deployNewProject{value: PROJECT_CREATION_FEE}(brandConfig, projectOwner, prices);
        project = Project(payable(projectAddr));
    }

    // ==================== Factory Untested Functions ====================

    function test_Factory_GetRevenueStats() public {
        // Create some subscriptions to generate revenue
        vm.deal(subscriber, 1 ether);
        vm.prank(subscriber);
        project.subscribe{value: PRO_MONTHLY}(
            DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.MONTHLY, address(0)
        );

        // Get revenue stats
        (uint256 totalProjectRevenue, uint256 totalPlatformFees, uint256 totalReferralRewards, uint256 totalCashback) =
            factory.getRevenueStats();

        assertGt(totalProjectRevenue, 0, "Should have project revenue");
        assertGt(totalPlatformFees, 0, "Should have platform fees");
        assertEq(totalReferralRewards, 0, "No referral rewards yet");
        assertGt(totalCashback, 0, "Should have cashback");
    }

    // Ownership handover functions are disabled in both Factory and Project
    // They revert with "This function is disabled" message

    // ==================== Project Untested Functions ====================

    function test_Project_GetBrandConfig() public {
        // Call view function through fallback proxy
        (bool success, bytes memory data) = address(project).staticcall(abi.encodeWithSignature("getBrandConfig()"));
        require(success, "getBrandConfig failed");
        DataTypes.BrandConfig memory config = abi.decode(data, (DataTypes.BrandConfig));

        assertEq(config.name, "TestProject", "Name should match");
        assertEq(config.symbol, "TP", "Symbol should match");
        assertEq(config.description, "Test Description", "Description should match");
        assertEq(config.logoUri, "https://logo.com", "Logo URI should match");
        assertEq(config.websiteUrl, "https://website.com", "Website should match");
        assertEq(uint8(config.maxTier), uint8(DataTypes.SubscriptionTier.MAX), "Max tier should match");
    }

    function test_Project_GetEnabledPeriods() public view {
        (bool success2, bytes memory data2) =
            address(project).staticcall(abi.encodeWithSignature("getEnabledPeriods()"));
        require(success2, "getEnabledPeriods failed");
        bool[4] memory periods = abi.decode(data2, (bool[4]));

        assertFalse(periods[0], "Daily should be disabled");
        assertFalse(periods[1], "Weekly should be disabled");
        assertTrue(periods[2], "Monthly should be enabled");
        assertTrue(periods[3], "Yearly should be enabled");
    }

    function test_Project_OperationHistory() public {
        // Create some operations
        vm.deal(subscriber, 1 ether);
        vm.startPrank(subscriber);

        // Subscribe
        project.subscribe{value: PRO_MONTHLY}(
            DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.MONTHLY, address(0)
        );

        // Fast forward and renew
        vm.warp(block.timestamp + 31 days);
        project.renew{value: PRO_MONTHLY}(DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.MONTHLY);
        vm.stopPrank();

        // Get global operation history
        (bool success3, bytes memory data3) =
            address(project).staticcall(abi.encodeWithSignature("getOperationHistoryPaginated(uint256,uint256)", 0, 10));
        require(success3, "getOperationHistoryPaginated failed");
        (DataTypes.OperationRecord[] memory records, uint256 total) =
            abi.decode(data3, (DataTypes.OperationRecord[], uint256));

        assertEq(total, 2, "Should have 2 operations");
        assertEq(records.length, 2, "Should return 2 records");
        assertEq(uint8(records[0].operationType), uint8(DataTypes.OperationType.SUBSCRIBE), "First should be subscribe");
        assertEq(uint8(records[1].operationType), uint8(DataTypes.OperationType.RENEW), "Second should be renew");

        // Get user operation history
        (bool success4, bytes memory data4) = address(project).staticcall(
            abi.encodeWithSignature("getUserOperationHistoryPaginated(address,uint256,uint256)", subscriber, 0, 10)
        );
        require(success4, "getUserOperationHistoryPaginated failed");
        (DataTypes.OperationRecord[] memory userRecords, uint256 userTotal) =
            abi.decode(data4, (DataTypes.OperationRecord[], uint256));

        assertEq(userTotal, 2, "User should have 2 operations");
        assertEq(userRecords.length, 2, "Should return 2 user records");
        assertEq(userRecords[0].user, subscriber, "Should be subscriber's record");
    }

    function test_Project_GetWithdrawableBalance() public {
        // Create subscription to generate revenue
        vm.deal(subscriber, 1 ether);
        vm.prank(subscriber);
        project.subscribe{value: PRO_MONTHLY}(
            DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.MONTHLY, address(0)
        );

        (bool success5, bytes memory data5) =
            address(project).staticcall(abi.encodeWithSignature("getWithdrawableBalance()"));
        require(success5, "getWithdrawableBalance failed");
        (uint256 withdrawable, uint256 total, uint256 reserved) = abi.decode(data5, (uint256, uint256, uint256));

        assertGt(total, 0, "Should have total balance");
        assertEq(withdrawable, total - reserved, "Withdrawable should be total minus reserved");
        assertEq(reserved, 0, "No referral rewards to reserve");
    }

    function test_Project_HasActiveSubscription_False() public view {
        // Test with user who never subscribed
        (bool successActive, bytes memory dataActive) =
            address(project).staticcall(abi.encodeWithSignature("hasActiveSubscription(address)", address(0x999)));
        require(successActive, "hasActiveSubscription failed");
        bool hasActive = abi.decode(dataActive, (bool));
        assertFalse(hasActive, "Non-subscriber should not have active subscription");
    }

    function test_Project_GetReferralAccount_Empty() public view {
        // Test with user who never referred anyone
        (bool success6, bytes memory data6) =
            address(project).staticcall(abi.encodeWithSignature("getReferralAccount(address)", address(0x999)));
        require(success6, "getReferralAccount failed");
        DataTypes.ReferralAccount memory account = abi.decode(data6, (DataTypes.ReferralAccount));

        assertEq(account.referralCount, 0, "Should have no referrals");
        assertEq(account.totalRewards, 0, "Should have no rewards");
        assertEq(account.pendingRewards, 0, "Should have no pending rewards");
    }
}
