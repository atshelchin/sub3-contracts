// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Factory} from "../src/Factory.sol";
import {Project} from "../src/Project.sol";
import {DataTypes} from "../src/DataTypes.sol";
import {IProject} from "../src/interfaces/IProject.sol";

contract ProjectTest is Test {
    Factory factory;
    Project projectImpl;
    Project project;

    address owner = address(0x1);
    address subscriber1 = address(0x2);
    address subscriber2 = address(0x3);
    address referrer = address(0x4);
    address nonSubscriber = address(0x5);

    DataTypes.BrandConfig brandConfig;

    uint256 constant CREATION_FEE = 0.01 ether;
    uint256 constant PRO_MONTHLY = 0.01 ether;
    uint256 constant PRO_YEARLY = 0.1 ether;
    uint256 constant MAX_MONTHLY = 0.03 ether;
    uint256 constant MAX_YEARLY = 0.3 ether;

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

    event ReferralRewardAccrued(
        address indexed referrer, address indexed subscriber, uint256 referrerReward, uint256 subscriberReward
    );

    event ReferralRewardsClaimed(address indexed referrer, uint256 amount);

    event PlanConfigUpdated(
        DataTypes.SubscriptionTier tier, uint256 monthlyPrice, uint256 yearlyPrice, string[] features
    );

    event BrandConfigUpdated(string name, string symbol);
    event Withdrawn(address indexed to, uint256 amount);

    function setUp() public {
        // Deploy factory
        projectImpl = new Project();
        factory = new Factory(owner, address(projectImpl));

        // Setup brand config
        brandConfig = DataTypes.BrandConfig({
            name: "TestProject",
            symbol: "TP",
            description: "Test subscription project",
            logoUri: "https://example.com/logo.png",
            websiteUrl: "https://example.com",
            primaryColor: "#FF0000"
        });

        // Deploy project through factory
        vm.deal(owner, 1 ether);
        vm.prank(owner);
        address projectAddr = factory.deployNewProject{value: CREATION_FEE}(brandConfig, owner);
        project = Project(payable(projectAddr));

        // Fund test accounts
        vm.deal(subscriber1, 10 ether);
        vm.deal(subscriber2, 10 ether);
        vm.deal(referrer, 10 ether);
        vm.deal(nonSubscriber, 10 ether);
    }

    // ==================== Initialization Tests ====================

    function test_Initialization() public view {
        // Check brand config
        (string memory name, string memory symbol,,,,) = project.brandConfig();
        assertEq(name, "TestProject");
        assertEq(symbol, "TP");

        // Check factory
        assertEq(project.factory(), address(factory));

        // Check owner
        assertEq(project.owner(), owner);

        // Check initialized
        assertTrue(project.initialized());
    }

    function test_CannotReinitialize() public {
        vm.expectRevert(IProject.ProjectAlreadyInitialized.selector);
        project.initialize(brandConfig, address(factory), owner);
    }

    function test_DefaultPlans() public view {
        // Check PRO plan
        DataTypes.SubscriptionPlan memory proPlan = project.getPlan(DataTypes.SubscriptionTier.PRO);
        assertEq(uint256(proPlan.tier), uint256(DataTypes.SubscriptionTier.PRO));
        assertEq(proPlan.monthlyPrice, PRO_MONTHLY);
        assertEq(proPlan.yearlyPrice, PRO_YEARLY);

        // Check MAX plan
        DataTypes.SubscriptionPlan memory maxPlan = project.getPlan(DataTypes.SubscriptionTier.MAX);
        assertEq(uint256(maxPlan.tier), uint256(DataTypes.SubscriptionTier.MAX));
        assertEq(maxPlan.monthlyPrice, MAX_MONTHLY);
        assertEq(maxPlan.yearlyPrice, MAX_YEARLY);
    }

    // ==================== Subscribe Tests ====================

    function test_SubscribeProMonthly() public {
        vm.prank(subscriber1);
        vm.expectEmit(true, true, true, false);
        emit Subscribed(
            subscriber1, DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.MONTHLY, PRO_MONTHLY, 0
        );

        project.subscribe{value: PRO_MONTHLY}(
            DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.MONTHLY, address(0)
        );

        // Check subscription
        DataTypes.UserSubscription memory sub = project.getUserSubscription(subscriber1);
        assertEq(sub.user, subscriber1);
        assertEq(uint256(sub.tier), uint256(DataTypes.SubscriptionTier.PRO));
        assertEq(uint256(sub.period), uint256(DataTypes.SubscriptionPeriod.MONTHLY));
        assertEq(sub.paidAmount, PRO_MONTHLY);
        assertTrue(project.hasActiveSubscription(subscriber1));

        // Check statistics
        (uint256 gross, uint256 net,,,,, uint256 platformFees,) = project.getProjectStats();
        assertEq(gross, PRO_MONTHLY);
        uint256 expectedPlatformFee = (PRO_MONTHLY * 500) / 10000; // 5%
        assertEq(platformFees, expectedPlatformFee);
        assertEq(net, PRO_MONTHLY - expectedPlatformFee);
    }

    function test_SubscribeMaxYearly() public {
        vm.prank(subscriber1);
        project.subscribe{value: MAX_YEARLY}(
            DataTypes.SubscriptionTier.MAX, DataTypes.SubscriptionPeriod.YEARLY, address(0)
        );

        DataTypes.UserSubscription memory sub = project.getUserSubscription(subscriber1);
        assertEq(uint256(sub.tier), uint256(DataTypes.SubscriptionTier.MAX));
        assertEq(uint256(sub.period), uint256(DataTypes.SubscriptionPeriod.YEARLY));
        assertEq(sub.paidAmount, MAX_YEARLY);
    }

    function test_SubscribeWithValidReferrer() public {
        // First, referrer subscribes
        vm.prank(referrer);
        project.subscribe{value: PRO_MONTHLY}(
            DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.MONTHLY, address(0)
        );

        // Then subscriber1 subscribes with referrer
        vm.prank(subscriber1);
        vm.expectEmit(true, true, true, true);
        emit ReferralRewardAccrued(referrer, subscriber1, PRO_MONTHLY / 10, PRO_MONTHLY / 10);

        project.subscribe{value: PRO_MONTHLY}(
            DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.MONTHLY, referrer
        );

        // Check referrer recorded
        DataTypes.UserSubscription memory sub = project.getUserSubscription(subscriber1);
        assertEq(sub.referrer, referrer);

        // Check referral account
        DataTypes.ReferralAccount memory refAccount = project.getReferralAccount(referrer);
        assertEq(refAccount.pendingRewards, PRO_MONTHLY / 10);
        assertEq(refAccount.totalRewards, PRO_MONTHLY / 10);
        assertEq(refAccount.referralCount, 1);

        // Check subscriber cashback
        assertEq(sub.totalRewardsEarned, PRO_MONTHLY / 10);

        // Check statistics
        (uint256 gross,,, uint256 referrers, uint256 validRevenue, uint256 rewards,, uint256 cashback) =
            project.getProjectStats();
        assertEq(gross, PRO_MONTHLY * 2); // Both subscriptions
        assertEq(referrers, 1);
        assertEq(validRevenue, PRO_MONTHLY); // Only subscriber1's payment had valid referrer
        assertEq(rewards, PRO_MONTHLY / 10); // Referrer rewards
        assertEq(cashback, PRO_MONTHLY / 10); // Subscriber cashback
    }

    function test_SubscribeWithInvalidReferrer() public {
        // subscriber1 subscribes with non-existent referrer (should not revert)
        vm.prank(subscriber1);
        project.subscribe{value: PRO_MONTHLY}(
            DataTypes.SubscriptionTier.PRO,
            DataTypes.SubscriptionPeriod.MONTHLY,
            nonSubscriber // Not subscribed
        );

        // Check no referrer recorded
        DataTypes.UserSubscription memory sub = project.getUserSubscription(subscriber1);
        assertEq(sub.referrer, address(0));

        // Check no referral rewards
        DataTypes.ReferralAccount memory refAccount = project.getReferralAccount(nonSubscriber);
        assertEq(refAccount.pendingRewards, 0);
    }

    function test_SubscribeWithExpiredReferrer() public {
        // Referrer subscribes
        vm.prank(referrer);
        project.subscribe{value: PRO_MONTHLY}(
            DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.MONTHLY, address(0)
        );

        // Fast forward past expiration
        vm.warp(block.timestamp + 31 days);

        // subscriber1 subscribes with expired referrer
        vm.prank(subscriber1);
        project.subscribe{value: PRO_MONTHLY}(
            DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.MONTHLY, referrer
        );

        // Check no referrer recorded
        DataTypes.UserSubscription memory sub = project.getUserSubscription(subscriber1);
        assertEq(sub.referrer, address(0));

        // Check no new referral rewards
        DataTypes.ReferralAccount memory refAccount = project.getReferralAccount(referrer);
        assertEq(refAccount.pendingRewards, 0);
    }

    function test_CannotSubscribeTwice() public {
        vm.prank(subscriber1);
        project.subscribe{value: PRO_MONTHLY}(
            DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.MONTHLY, address(0)
        );

        vm.prank(subscriber1);
        vm.expectRevert(IProject.AlreadySubscribed.selector);
        project.subscribe{value: PRO_MONTHLY}(
            DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.MONTHLY, address(0)
        );
    }

    function test_SubscribeInsufficientPayment() public {
        vm.prank(subscriber1);
        vm.expectRevert(IProject.InsufficientPayment.selector);
        project.subscribe{value: PRO_MONTHLY - 1}(
            DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.MONTHLY, address(0)
        );
    }

    function test_SubscribeExcessPayment() public {
        vm.prank(subscriber1);
        vm.expectRevert(IProject.ExcessPayment.selector);
        project.subscribe{value: PRO_MONTHLY + 1}(
            DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.MONTHLY, address(0)
        );
    }

    // ==================== Renew Tests ====================

    function test_RenewAfterExpiry() public {
        // Subscribe first
        vm.prank(subscriber1);
        project.subscribe{value: PRO_MONTHLY}(
            DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.MONTHLY, address(0)
        );

        // Fast forward past expiration
        vm.warp(block.timestamp + 31 days);

        // Renew
        vm.prank(subscriber1);
        vm.expectEmit(true, true, true, false);
        emit Renewed(subscriber1, DataTypes.SubscriptionPeriod.YEARLY, PRO_YEARLY, 0);

        project.renew{value: PRO_YEARLY}(DataTypes.SubscriptionPeriod.YEARLY);

        // Check renewed subscription
        DataTypes.UserSubscription memory sub = project.getUserSubscription(subscriber1);
        assertEq(uint256(sub.period), uint256(DataTypes.SubscriptionPeriod.YEARLY));
        assertEq(sub.paidAmount, PRO_YEARLY);
        assertTrue(project.hasActiveSubscription(subscriber1));
    }

    function test_CannotRenewWhileActive() public {
        vm.prank(subscriber1);
        project.subscribe{value: PRO_MONTHLY}(
            DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.MONTHLY, address(0)
        );

        vm.prank(subscriber1);
        vm.expectRevert(IProject.SubscriptionStillActive.selector);
        project.renew{value: PRO_MONTHLY}(DataTypes.SubscriptionPeriod.MONTHLY);
    }

    function test_CannotRenewWithoutSubscription() public {
        vm.prank(subscriber1);
        vm.expectRevert(IProject.NoActiveSubscription.selector);
        project.renew{value: PRO_MONTHLY}(DataTypes.SubscriptionPeriod.MONTHLY);
    }

    // ==================== Upgrade Tests ====================

    function test_UpgradeFromProToMax() public {
        // Subscribe to PRO monthly
        vm.prank(subscriber1);
        project.subscribe{value: PRO_MONTHLY}(
            DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.MONTHLY, address(0)
        );

        // Calculate upgrade cost
        uint256 remainingTime = 30 days;
        uint256 remainingNewCost = (MAX_MONTHLY * remainingTime) / 30 days;
        uint256 fullPeriodCost = MAX_MONTHLY;
        uint256 remainingOldCredit = (PRO_MONTHLY * remainingTime) / 30 days;
        uint256 upgradeCost = remainingNewCost + fullPeriodCost - remainingOldCredit;

        // Upgrade to MAX
        vm.prank(subscriber1);
        vm.expectEmit(true, true, true, false);
        emit Upgraded(subscriber1, DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionTier.MAX, upgradeCost, 0);

        project.upgrade{value: upgradeCost}(DataTypes.SubscriptionTier.MAX);

        // Check upgraded subscription
        DataTypes.UserSubscription memory sub = project.getUserSubscription(subscriber1);
        assertEq(uint256(sub.tier), uint256(DataTypes.SubscriptionTier.MAX));
        assertEq(sub.endTime, block.timestamp + 60 days); // Extended by one period
    }

    function test_CannotUpgradeToSameTier() public {
        vm.prank(subscriber1);
        project.subscribe{value: PRO_MONTHLY}(
            DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.MONTHLY, address(0)
        );

        vm.prank(subscriber1);
        vm.expectRevert(IProject.CannotUpgradeToSameTier.selector);
        project.upgrade{value: 1 ether}(DataTypes.SubscriptionTier.PRO);
    }

    function test_CannotUpgradeToLowerTier() public {
        vm.prank(subscriber1);
        project.subscribe{value: MAX_MONTHLY}(
            DataTypes.SubscriptionTier.MAX, DataTypes.SubscriptionPeriod.MONTHLY, address(0)
        );

        vm.prank(subscriber1);
        vm.expectRevert(IProject.InvalidTier.selector);
        project.upgrade{value: 1 ether}(DataTypes.SubscriptionTier.PRO);
    }

    function test_CannotUpgradeWhenExpired() public {
        vm.prank(subscriber1);
        project.subscribe{value: PRO_MONTHLY}(
            DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.MONTHLY, address(0)
        );

        vm.warp(block.timestamp + 31 days);

        vm.prank(subscriber1);
        vm.expectRevert(IProject.NoActiveSubscription.selector);
        project.upgrade{value: 1 ether}(DataTypes.SubscriptionTier.MAX);
    }

    // ==================== Downgrade Tests ====================

    function test_DowngradeAfterExpiry() public {
        // Subscribe to MAX
        vm.prank(subscriber1);
        project.subscribe{value: MAX_MONTHLY}(
            DataTypes.SubscriptionTier.MAX, DataTypes.SubscriptionPeriod.MONTHLY, address(0)
        );

        // Fast forward past expiration
        vm.warp(block.timestamp + 31 days);

        // Downgrade to PRO
        vm.prank(subscriber1);
        vm.expectEmit(true, true, true, false);
        emit Downgraded(
            subscriber1,
            DataTypes.SubscriptionTier.MAX,
            DataTypes.SubscriptionTier.PRO,
            DataTypes.SubscriptionPeriod.YEARLY,
            PRO_YEARLY,
            0
        );

        project.downgrade{value: PRO_YEARLY}(DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.YEARLY);

        // Check downgraded subscription
        DataTypes.UserSubscription memory sub = project.getUserSubscription(subscriber1);
        assertEq(uint256(sub.tier), uint256(DataTypes.SubscriptionTier.PRO));
        assertEq(uint256(sub.period), uint256(DataTypes.SubscriptionPeriod.YEARLY));
        assertTrue(project.hasActiveSubscription(subscriber1));
    }

    function test_CannotDowngradeWhileActive() public {
        vm.prank(subscriber1);
        project.subscribe{value: MAX_MONTHLY}(
            DataTypes.SubscriptionTier.MAX, DataTypes.SubscriptionPeriod.MONTHLY, address(0)
        );

        vm.prank(subscriber1);
        vm.expectRevert(IProject.SubscriptionStillActive.selector);
        project.downgrade{value: PRO_MONTHLY}(DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.MONTHLY);
    }

    function test_CannotDowngradeToSameOrHigherTier() public {
        vm.prank(subscriber1);
        project.subscribe{value: PRO_MONTHLY}(
            DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.MONTHLY, address(0)
        );

        vm.warp(block.timestamp + 31 days);

        vm.prank(subscriber1);
        vm.expectRevert(IProject.CannotDowngradeToSameTier.selector);
        project.downgrade{value: MAX_MONTHLY}(DataTypes.SubscriptionTier.MAX, DataTypes.SubscriptionPeriod.MONTHLY);
    }

    // ==================== Referral Rewards Tests ====================

    function test_ClaimReferralRewards() public {
        // Setup: referrer subscribes
        vm.prank(referrer);
        project.subscribe{value: PRO_MONTHLY}(
            DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.MONTHLY, address(0)
        );

        // subscriber1 subscribes with referrer
        vm.prank(subscriber1);
        project.subscribe{value: MAX_MONTHLY}(
            DataTypes.SubscriptionTier.MAX, DataTypes.SubscriptionPeriod.MONTHLY, referrer
        );

        // Wait for cooldown
        vm.warp(block.timestamp + 7 days);

        // Claim rewards
        uint256 balanceBefore = referrer.balance;
        vm.prank(referrer);
        vm.expectEmit(true, true, true, true);
        emit ReferralRewardsClaimed(referrer, MAX_MONTHLY / 10);

        project.claimReferralRewards();

        // Check rewards claimed
        assertEq(referrer.balance - balanceBefore, MAX_MONTHLY / 10);

        DataTypes.ReferralAccount memory refAccount = project.getReferralAccount(referrer);
        assertEq(refAccount.pendingRewards, 0);
        assertEq(refAccount.totalRewards, MAX_MONTHLY / 10);
    }

    function test_CannotClaimBeforeCooldown() public {
        // Setup referral
        vm.prank(referrer);
        project.subscribe{value: PRO_MONTHLY}(
            DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.MONTHLY, address(0)
        );

        vm.prank(subscriber1);
        project.subscribe{value: PRO_MONTHLY}(
            DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.MONTHLY, referrer
        );

        // Wait for cooldown
        vm.warp(block.timestamp + 7 days);

        // First claim should succeed
        vm.prank(referrer);
        project.claimReferralRewards();

        // Fast forward less than cooldown
        vm.warp(block.timestamp + 6 days);

        // Second user subscribes to generate more rewards
        vm.prank(subscriber2);
        project.subscribe{value: MAX_MONTHLY}(
            DataTypes.SubscriptionTier.MAX, DataTypes.SubscriptionPeriod.MONTHLY, referrer
        );

        // Try to claim again before cooldown expires
        vm.prank(referrer);
        vm.expectRevert(IProject.ClaimCooldownNotMet.selector);
        project.claimReferralRewards();
    }

    function test_CannotClaimWithNoRewards() public {
        vm.prank(subscriber1);
        vm.expectRevert(IProject.NoRewardsToClaim.selector);
        project.claimReferralRewards();
    }

    // ==================== Admin Functions Tests ====================

    function test_SetPlanConfig() public {
        string[] memory features = new string[](2);
        features[0] = "Feature 1";
        features[1] = "Feature 2";

        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit PlanConfigUpdated(DataTypes.SubscriptionTier.PRO, 0.02 ether, 0.2 ether, features);

        project.setPlanConfig(DataTypes.SubscriptionTier.PRO, 0.02 ether, 0.2 ether, features);

        DataTypes.SubscriptionPlan memory plan = project.getPlan(DataTypes.SubscriptionTier.PRO);
        assertEq(plan.monthlyPrice, 0.02 ether);
        assertEq(plan.yearlyPrice, 0.2 ether);
        assertEq(plan.features.length, 2);
        assertEq(plan.features[0], "Feature 1");
    }

    function test_OnlyOwnerCanSetPlanConfig() public {
        string[] memory features = new string[](0);

        vm.prank(subscriber1);
        vm.expectRevert(); // Ownable unauthorized
        project.setPlanConfig(DataTypes.SubscriptionTier.PRO, 0.02 ether, 0.2 ether, features);
    }

    function test_CannotSetZeroPrice() public {
        string[] memory features = new string[](0);

        vm.prank(owner);
        vm.expectRevert(IProject.InvalidPrice.selector);
        project.setPlanConfig(DataTypes.SubscriptionTier.PRO, 0, 0.2 ether, features);
    }

    function test_UpdateBrandConfig() public {
        DataTypes.BrandConfig memory newConfig = DataTypes.BrandConfig({
            name: "TestProject", // Must be same
            symbol: "TP", // Must be same
            description: "Updated description",
            logoUri: "https://newlogo.com",
            websiteUrl: "https://newsite.com",
            primaryColor: "#00FF00"
        });

        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit BrandConfigUpdated("TestProject", "TP");

        project.updateBrandConfig(newConfig);

        (,, string memory desc, string memory logo, string memory website, string memory color) = project.brandConfig();
        assertEq(desc, "Updated description");
        assertEq(logo, "https://newlogo.com");
        assertEq(website, "https://newsite.com");
        assertEq(color, "#00FF00");
    }

    function test_CannotChangeNameOrSymbol() public {
        DataTypes.BrandConfig memory newConfig = DataTypes.BrandConfig({
            name: "DifferentName",
            symbol: "TP",
            description: "Updated",
            logoUri: "",
            websiteUrl: "",
            primaryColor: ""
        });

        vm.prank(owner);
        vm.expectRevert("Name cannot be changed");
        project.updateBrandConfig(newConfig);

        newConfig.name = "TestProject";
        newConfig.symbol = "DIFF";

        vm.prank(owner);
        vm.expectRevert("Symbol cannot be changed");
        project.updateBrandConfig(newConfig);
    }

    function test_Withdraw() public {
        // Add some funds to contract
        vm.deal(address(project), 1 ether);

        uint256 balanceBefore = owner.balance;

        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit Withdrawn(owner, 0.5 ether);

        project.withdraw(owner, 0.5 ether);

        assertEq(owner.balance - balanceBefore, 0.5 ether);
        assertEq(address(project).balance, 0.5 ether);
    }

    function test_CannotWithdrawMoreThanBalance() public {
        vm.deal(address(project), 0.5 ether);

        vm.prank(owner);
        vm.expectRevert(IProject.InsufficientBalance.selector);
        project.withdraw(owner, 1 ether);
    }

    function test_CannotWithdrawToZeroAddress() public {
        vm.deal(address(project), 1 ether);

        vm.prank(owner);
        vm.expectRevert(IProject.ZeroAddress.selector);
        project.withdraw(address(0), 0.5 ether);
    }

    function test_CannotWithdrawZeroAmount() public {
        vm.deal(address(project), 1 ether);

        vm.prank(owner);
        vm.expectRevert(IProject.ZeroAmount.selector);
        project.withdraw(owner, 0);
    }

    // ==================== View Functions Tests ====================

    function test_GetAllPlans() public view {
        DataTypes.SubscriptionPlan[] memory plans = project.getAllPlans();
        assertEq(plans.length, 2);
        assertEq(uint256(plans[0].tier), uint256(DataTypes.SubscriptionTier.PRO));
        assertEq(uint256(plans[1].tier), uint256(DataTypes.SubscriptionTier.MAX));
    }

    function test_GetReferralStats() public {
        // Setup referrals
        vm.prank(referrer);
        project.subscribe{value: PRO_MONTHLY}(
            DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.MONTHLY, address(0)
        );

        vm.prank(subscriber1);
        project.subscribe{value: PRO_MONTHLY}(
            DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.MONTHLY, referrer
        );

        vm.prank(subscriber2);
        project.subscribe{value: MAX_MONTHLY}(
            DataTypes.SubscriptionTier.MAX, DataTypes.SubscriptionPeriod.MONTHLY, referrer
        );

        (uint256 totalSubs, uint256 totalRewards) = project.getReferralStats();
        assertEq(totalSubs, 2);
        assertEq(totalRewards, (PRO_MONTHLY + MAX_MONTHLY) / 10);
    }

    function test_GetUserTotalRewards() public {
        // Setup
        vm.prank(referrer);
        project.subscribe{value: PRO_MONTHLY}(
            DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.MONTHLY, address(0)
        );

        vm.prank(subscriber1);
        project.subscribe{value: MAX_MONTHLY}(
            DataTypes.SubscriptionTier.MAX, DataTypes.SubscriptionPeriod.MONTHLY, referrer
        );

        uint256 rewards = project.getUserTotalRewards(subscriber1);
        assertEq(rewards, MAX_MONTHLY / 10);
    }

    function test_GetProjectStats() public {
        // Create subscriptions with referrals
        vm.prank(referrer);
        project.subscribe{value: PRO_MONTHLY}(
            DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.MONTHLY, address(0)
        );

        vm.prank(subscriber1);
        project.subscribe{value: MAX_MONTHLY}(
            DataTypes.SubscriptionTier.MAX, DataTypes.SubscriptionPeriod.MONTHLY, referrer
        );

        (
            uint256 grossRevenue,
            uint256 netRevenue,
            uint256 subscribers,
            uint256 referrers,
            uint256 validReferralRevenue,
            uint256 referralRewards,
            uint256 platformFees,
            uint256 cashbackPaid
        ) = project.getProjectStats();

        uint256 totalRevenue = PRO_MONTHLY + MAX_MONTHLY;
        assertEq(grossRevenue, totalRevenue);
        assertEq(subscribers, 2);
        assertEq(referrers, 1);
        assertEq(validReferralRevenue, MAX_MONTHLY); // Only subscriber1's payment had valid referrer
        assertEq(referralRewards, MAX_MONTHLY / 10);
        assertEq(cashbackPaid, MAX_MONTHLY / 10);

        // Platform fees: 5% of total
        uint256 expectedPlatformFees = (totalRevenue * 500) / 10000;
        assertEq(platformFees, expectedPlatformFees);

        // Net revenue: gross - platform fees - cashback
        assertEq(netRevenue, totalRevenue - expectedPlatformFees - (MAX_MONTHLY / 10));
    }

    // ==================== Edge Cases and Security Tests ====================

    function test_InvalidTier() public {
        // Create raw call data with invalid tier value
        bytes memory data = abi.encodeWithSelector(
            IProject.subscribe.selector,
            uint8(10), // Invalid tier
            DataTypes.SubscriptionPeriod.MONTHLY,
            address(0)
        );

        vm.prank(subscriber1);
        vm.expectRevert(IProject.InvalidTier.selector);
        (bool success,) = address(project).call{value: 1 ether}(data);
        require(!success, "Call should have reverted");
    }

    function test_InvalidPeriod() public {
        // Create raw call data with invalid period value
        bytes memory data = abi.encodeWithSelector(
            IProject.subscribe.selector,
            DataTypes.SubscriptionTier.PRO,
            uint8(10), // Invalid period
            address(0)
        );

        vm.prank(subscriber1);
        vm.expectRevert(IProject.InvalidPeriod.selector);
        (bool success,) = address(project).call{value: 1 ether}(data);
        require(!success, "Call should have reverted");
    }

    function test_ReentrancyProtection() public {
        // Create a malicious contract that tries to reenter
        ReentrantAttacker attacker = new ReentrantAttacker(project);
        vm.deal(address(attacker), 10 ether);

        // Try to attack during withdraw (which makes external calls)
        // First subscribe as attacker to have something to claim
        vm.prank(address(attacker));
        project.subscribe{value: PRO_MONTHLY}(
            DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.MONTHLY, address(0)
        );

        // Now have someone subscribe with attacker as referrer
        vm.prank(subscriber1);
        project.subscribe{value: PRO_MONTHLY}(
            DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.MONTHLY, address(attacker)
        );

        // Wait for cooldown
        vm.warp(block.timestamp + 7 days);

        // Try to claim and reenter
        vm.expectRevert(); // ReentrancyGuard should prevent reentrancy
        attacker.attackClaim();
    }

    function test_ReceiveFunction() public {
        // Contract can receive ETH
        uint256 balanceBefore = address(project).balance;
        vm.deal(subscriber1, 1 ether);
        vm.prank(subscriber1);
        (bool success,) = address(project).call{value: 0.1 ether}("");
        assertTrue(success);
        assertEq(address(project).balance - balanceBefore, 0.1 ether);
    }

    function test_MultipleReferralsTracking() public {
        // Referrer subscribes
        vm.prank(referrer);
        project.subscribe{value: PRO_MONTHLY}(
            DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.MONTHLY, address(0)
        );

        // Multiple users subscribe with same referrer
        address[] memory subscribers = new address[](5);
        for (uint256 i = 0; i < 5; i++) {
            subscribers[i] = address(uint160(100 + i));
            vm.deal(subscribers[i], 1 ether);
            vm.prank(subscribers[i]);
            project.subscribe{value: PRO_MONTHLY}(
                DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.MONTHLY, referrer
            );
        }

        // Check referral account
        DataTypes.ReferralAccount memory refAccount = project.getReferralAccount(referrer);
        assertEq(refAccount.referralCount, 5);
        assertEq(refAccount.pendingRewards, (PRO_MONTHLY * 5) / 10);
        assertEq(refAccount.totalRewards, (PRO_MONTHLY * 5) / 10);
    }

    function test_UpgradeWithReferralTracking() public {
        // Setup with referral
        vm.prank(referrer);
        project.subscribe{value: PRO_MONTHLY}(
            DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.MONTHLY, address(0)
        );

        vm.prank(subscriber1);
        project.subscribe{value: PRO_MONTHLY}(
            DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.MONTHLY, referrer
        );

        // Upgrade should also process referral rewards
        uint256 upgradeCost = MAX_MONTHLY * 2 - PRO_MONTHLY; // Simplified calculation
        vm.prank(subscriber1);
        project.upgrade{value: upgradeCost}(DataTypes.SubscriptionTier.MAX);

        // Check additional rewards
        DataTypes.ReferralAccount memory refAccount = project.getReferralAccount(referrer);
        assertTrue(refAccount.pendingRewards > PRO_MONTHLY / 10);
    }
}

// Helper contract for reentrancy testing
contract ReentrantAttacker {
    Project target;
    bool attacking;

    constructor(Project _target) {
        target = _target;
    }

    function attackClaim() external {
        attacking = true;
        target.claimReferralRewards();
    }

    receive() external payable {
        if (attacking && address(target).balance > 0.01 ether) {
            attacking = false; // Prevent infinite loop
            // Try to claim again during the first claim
            target.claimReferralRewards();
        }
    }
}
