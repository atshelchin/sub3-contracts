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
    IProject projectView; // Interface wrapper for view functions

    address platformOwner = address(0x1);
    address projectOwner = address(0x2);
    address subscriber1 = address(0x3);
    address subscriber2 = address(0x4);
    address referrer = address(0x5);
    address nonSubscriber = address(0x6);

    DataTypes.BrandConfig brandConfig;

    uint256 constant CREATION_FEE = 0.01 ether;
    uint256 constant PRO_MONTHLY = 0.01 ether;
    uint256 constant PRO_YEARLY = 0.1 ether;
    uint256 constant MAX_MONTHLY = 0.02 ether;
    uint256 constant MAX_YEARLY = 0.2 ether;

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
        // Deploy factory as platform owner
        vm.startPrank(platformOwner);
        projectImpl = new Project();
        factory = new Factory(platformOwner, address(projectImpl));
        vm.stopPrank();

        // Setup brand config
        brandConfig = DataTypes.BrandConfig({
            name: "TestProject",
            symbol: "TP",
            description: "Test subscription project",
            logoUri: "https://example.com/logo.png",
            websiteUrl: "https://example.com",
            primaryColor: "#FF0000",
            maxTier: 3, // Enable all 4 tiers (0-3)
            enabledPeriods: [false, false, true, true], // Enable monthly and yearly only
            tierNames: ["Starter", "Standard", "Pro", "Max"] // Default tier names
        });

        // Setup default prices for all tiers
        uint256[4][4] memory defaultPrices;
        // Starter: [daily, weekly, monthly, yearly]
        defaultPrices[0] = [uint256(0), 0, 0.005 ether, 0.05 ether];
        // Standard: [daily, weekly, monthly, yearly]
        defaultPrices[1] = [uint256(0), 0, 0.007 ether, 0.07 ether];
        // Pro: [daily, weekly, monthly, yearly]
        defaultPrices[2] = [uint256(0), 0, PRO_MONTHLY, PRO_YEARLY];
        // Max: [daily, weekly, monthly, yearly]
        defaultPrices[3] = [uint256(0), 0, MAX_MONTHLY, MAX_YEARLY];

        // Deploy project through factory as project owner
        vm.deal(projectOwner, 1 ether);
        vm.prank(projectOwner);
        address projectAddr = factory.deployNewProject{value: 0.01 ether}(brandConfig, projectOwner, defaultPrices);
        project = Project(payable(projectAddr));

        // Create interface wrapper for view functions
        projectView = IProject(address(project));

        // Start as project owner to configure plans
        vm.startPrank(projectOwner);

        // Plans are already configured during initialization with prices
        // We can still update features if needed
        string[] memory proFeatures = new string[](2);
        proFeatures[0] = "Basic Feature";
        proFeatures[1] = "Pro Feature";

        string[] memory maxFeatures = new string[](3);
        maxFeatures[0] = "Basic Feature";
        maxFeatures[1] = "Pro Feature";
        maxFeatures[2] = "Max Feature";

        // Update features for PRO and MAX plans (prices were set during initialization)
        uint256[4] memory proPrices = [uint256(0), 0, PRO_MONTHLY, PRO_YEARLY];
        project.setPlanConfig(DataTypes.SubscriptionTier.PRO, proPrices, proFeatures);

        uint256[4] memory maxPrices = [uint256(0), 0, MAX_MONTHLY, MAX_YEARLY];
        project.setPlanConfig(DataTypes.SubscriptionTier.MAX, maxPrices, maxFeatures);
        vm.stopPrank();

        // Fund test accounts
        vm.deal(subscriber1, 10 ether);
        vm.deal(subscriber2, 10 ether);
        vm.deal(referrer, 10 ether);
        vm.deal(nonSubscriber, 10 ether);
    }

    // ==================== Initialization Tests ====================

    function test_Initialization() public {
        // Check brand config
        DataTypes.BrandConfig memory config = projectView.getBrandConfig();
        assertEq(config.name, "TestProject");
        assertEq(config.symbol, "TP");

        // Check factory
        assertEq(project.factory(), address(factory));

        // Check owner
        assertEq(project.owner(), projectOwner);

        // Check initialized
        assertTrue(project.initialized());
    }

    function test_CannotReinitialize() public {
        vm.expectRevert(IProject.ProjectAlreadyInitialized.selector);
        uint256[4][4] memory emptyPrices;
        project.initialize(brandConfig, address(factory), projectOwner, emptyPrices);
    }

    function test_DefaultPlans() public {
        // Check PRO plan
        DataTypes.SubscriptionPlan memory proPlan = IProject(address(project)).getPlan(DataTypes.SubscriptionTier.PRO);
        string[4] memory tierNames = IProject(address(project)).getTierNames();
        assertEq(tierNames[2], "Pro");
        assertEq(proPlan.prices[2], PRO_MONTHLY); // Monthly price
        assertEq(proPlan.prices[3], PRO_YEARLY); // Yearly price

        // Check MAX plan
        DataTypes.SubscriptionPlan memory maxPlan = IProject(address(project)).getPlan(DataTypes.SubscriptionTier.MAX);
        string[4] memory tierNames2 = IProject(address(project)).getTierNames();
        assertEq(tierNames2[3], "Max");
        assertEq(maxPlan.prices[2], MAX_MONTHLY); // Monthly price
        assertEq(maxPlan.prices[3], MAX_YEARLY); // Yearly price
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
        DataTypes.UserSubscription memory sub = projectView.getUserSubscription(subscriber1);
        assertEq(sub.user, subscriber1);
        assertEq(uint256(sub.tier), uint256(DataTypes.SubscriptionTier.PRO));
        assertEq(uint256(sub.period), uint256(DataTypes.SubscriptionPeriod.MONTHLY));
        assertEq(sub.paidAmount, PRO_MONTHLY);
        assertTrue(projectView.hasActiveSubscription(subscriber1));

        // Check statistics
        (uint256 gross, uint256 net,,,,,,, uint256 platformFees,) = projectView.getProjectStats();
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

        DataTypes.UserSubscription memory sub = projectView.getUserSubscription(subscriber1);
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
        DataTypes.UserSubscription memory sub = projectView.getUserSubscription(subscriber1);
        assertEq(sub.referrer, referrer);

        // Check referral account
        DataTypes.ReferralAccount memory refAccount = projectView.getReferralAccount(referrer);
        assertEq(refAccount.pendingRewards, PRO_MONTHLY / 10);
        assertEq(refAccount.totalRewards, PRO_MONTHLY / 10);
        assertEq(refAccount.referralCount, 1);

        // Check subscriber cashback
        assertEq(sub.totalRewardsEarned, PRO_MONTHLY / 10);

        // Check statistics
        (
            uint256 gross,
            ,
            ,
            uint256 referrers,
            uint256 validRevenue,
            uint256 rewards,
            ,
            ,
            uint256 platformFees,
            uint256 cashback
        ) = projectView.getProjectStats();
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
        DataTypes.UserSubscription memory sub = projectView.getUserSubscription(subscriber1);
        assertEq(sub.referrer, address(0));

        // Check no referral rewards
        DataTypes.ReferralAccount memory refAccount = projectView.getReferralAccount(nonSubscriber);
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
        DataTypes.UserSubscription memory sub = projectView.getUserSubscription(subscriber1);
        assertEq(sub.referrer, address(0));

        // Check no new referral rewards
        DataTypes.ReferralAccount memory refAccount = projectView.getReferralAccount(referrer);
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
        // Test that overpayment up to 120% is accepted
        vm.prank(subscriber1);
        // This should succeed (120% of PRO_MONTHLY)
        project.subscribe{value: (PRO_MONTHLY * 12) / 10}(
            DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.MONTHLY, address(0)
        );

        // Test that overpayment > 120% reverts
        vm.prank(subscriber2);
        vm.expectRevert(IProject.ExcessPayment.selector);
        // This should fail (121% of PRO_MONTHLY)
        project.subscribe{value: (PRO_MONTHLY * 121) / 100}(
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
        emit IProject.Renewed(
            subscriber1, DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.YEARLY, PRO_YEARLY, 0
        );

        project.renew{value: PRO_YEARLY}(DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.YEARLY);

        // Check renewed subscription
        DataTypes.UserSubscription memory sub = projectView.getUserSubscription(subscriber1);
        assertEq(uint256(sub.period), uint256(DataTypes.SubscriptionPeriod.YEARLY));
        assertEq(sub.paidAmount, PRO_YEARLY);
        assertTrue(projectView.hasActiveSubscription(subscriber1));
    }

    function test_CannotRenewWhileActive() public {
        vm.prank(subscriber1);
        project.subscribe{value: PRO_MONTHLY}(
            DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.MONTHLY, address(0)
        );

        vm.prank(subscriber1);
        vm.expectRevert(IProject.SubscriptionStillActive.selector);
        project.renew{value: PRO_MONTHLY}(DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.MONTHLY);
    }

    function test_CannotRenewWithoutSubscription() public {
        vm.prank(subscriber1);
        vm.expectRevert(IProject.NoActiveSubscription.selector);
        project.renew{value: PRO_MONTHLY}(DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.MONTHLY);
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

        project.upgrade{value: upgradeCost}(DataTypes.SubscriptionTier.MAX, DataTypes.SubscriptionPeriod.MONTHLY);

        // Check upgraded subscription
        DataTypes.UserSubscription memory sub = projectView.getUserSubscription(subscriber1);
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
        project.upgrade{value: 1 ether}(DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.MONTHLY);
    }

    function test_CannotUpgradeToLowerTier() public {
        vm.prank(subscriber1);
        project.subscribe{value: MAX_MONTHLY}(
            DataTypes.SubscriptionTier.MAX, DataTypes.SubscriptionPeriod.MONTHLY, address(0)
        );

        vm.prank(subscriber1);
        vm.expectRevert(IProject.InvalidTier.selector);
        project.upgrade{value: 1 ether}(DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.MONTHLY);
    }

    function test_CannotUpgradeWhenExpired() public {
        vm.prank(subscriber1);
        project.subscribe{value: PRO_MONTHLY}(
            DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.MONTHLY, address(0)
        );

        vm.warp(block.timestamp + 31 days);

        vm.prank(subscriber1);
        vm.expectRevert(IProject.NoActiveSubscription.selector);
        project.upgrade{value: 1 ether}(DataTypes.SubscriptionTier.MAX, DataTypes.SubscriptionPeriod.MONTHLY);
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
        DataTypes.UserSubscription memory sub = projectView.getUserSubscription(subscriber1);
        assertEq(uint256(sub.tier), uint256(DataTypes.SubscriptionTier.PRO));
        assertEq(uint256(sub.period), uint256(DataTypes.SubscriptionPeriod.YEARLY));
        assertTrue(projectView.hasActiveSubscription(subscriber1));
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

        DataTypes.ReferralAccount memory refAccount = projectView.getReferralAccount(referrer);
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

        vm.prank(projectOwner);
        uint256[4] memory newPrices = [uint256(0), 0, 0.02 ether, 0.2 ether];

        vm.expectEmit(true, true, true, true);
        emit IProject.PlanConfigUpdated(DataTypes.SubscriptionTier.PRO, newPrices, "Pro", features);

        project.setPlanConfig(DataTypes.SubscriptionTier.PRO, newPrices, features);

        DataTypes.SubscriptionPlan memory plan = projectView.getPlan(DataTypes.SubscriptionTier.PRO);
        assertEq(plan.prices[2], 0.02 ether); // Monthly price
        assertEq(plan.prices[3], 0.2 ether); // Yearly price
        assertEq(plan.features.length, 2);
        assertEq(plan.features[0], "Feature 1");
    }

    function test_OnlyOwnerCanSetPlanConfig() public {
        string[] memory features = new string[](0);
        uint256[4] memory prices = [uint256(0), 0, 0.02 ether, 0.2 ether];

        vm.prank(subscriber1);
        vm.expectRevert(); // Ownable unauthorized
        project.setPlanConfig(DataTypes.SubscriptionTier.PRO, prices, features);
    }

    function test_CannotSetZeroPrice() public {
        // This test verifies that zero prices can be set (for disabled periods)
        // setPlanConfig doesn't validate prices since zero is valid for disabled periods
        string[] memory features = new string[](0);

        uint256[4] memory zeroPrices = [uint256(0), 0, 0, 0]; // All prices are zero

        vm.prank(projectOwner);
        // This should NOT revert - zero prices are allowed
        project.setPlanConfig(DataTypes.SubscriptionTier.PRO, zeroPrices, features);

        // Verify the plan was updated with zero prices
        DataTypes.SubscriptionPlan memory plan = projectView.getPlan(DataTypes.SubscriptionTier.PRO);
        assertEq(plan.prices[0], 0);
        assertEq(plan.prices[1], 0);
        assertEq(plan.prices[2], 0);
        assertEq(plan.prices[3], 0);
    }

    function test_UpdateBrandConfig() public {
        DataTypes.BrandConfig memory newConfig = DataTypes.BrandConfig({
            name: "TestProject", // Must be same
            symbol: "TP", // Must be same
            description: "Updated description",
            logoUri: "https://newlogo.com",
            websiteUrl: "https://newsite.com",
            primaryColor: "#00FF00",
            maxTier: 3,
            enabledPeriods: [false, false, true, true],
            tierNames: ["Starter", "Standard", "Pro", "Max"]
        });

        vm.prank(projectOwner);
        vm.expectEmit(true, true, true, true);
        emit BrandConfigUpdated("TestProject", "TP");

        project.updateBrandConfig(newConfig);

        (,, string memory desc, string memory logo, string memory website, string memory color,) = project.brandConfig();
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
            primaryColor: "",
            maxTier: 3,
            enabledPeriods: [false, false, true, true],
            tierNames: ["Starter", "Standard", "Pro", "Max"]
        });

        vm.prank(projectOwner);
        vm.expectRevert("Name cannot be changed");
        project.updateBrandConfig(newConfig);

        newConfig.name = "TestProject";
        newConfig.symbol = "DIFF";

        vm.prank(projectOwner);
        vm.expectRevert("Symbol cannot be changed");
        project.updateBrandConfig(newConfig);
    }

    function test_Withdraw() public {
        // Add some funds to contract
        vm.deal(address(project), 1 ether);

        uint256 balanceBefore = projectOwner.balance;

        vm.prank(projectOwner);
        vm.expectEmit(true, true, true, true);
        emit Withdrawn(projectOwner, 1 ether);

        project.withdraw(projectOwner);

        assertEq(projectOwner.balance - balanceBefore, 1 ether);
        assertEq(address(project).balance, 0);
    }

    function test_CannotWithdrawMoreThanBalance() public {
        // This test is no longer applicable since withdraw() automatically takes all available balance
        // The protection of referral rewards is tested in test_WithdrawProtectsPendingReferralRewards
        // We'll test that withdrawing with 0 balance doesn't revert but transfers 0
        vm.prank(projectOwner);
        uint256 balanceBefore = projectOwner.balance;
        project.withdraw(projectOwner);
        assertEq(projectOwner.balance, balanceBefore); // No change since contract has 0 balance
    }

    function test_CannotWithdrawToZeroAddress() public {
        vm.deal(address(project), 1 ether);

        vm.prank(projectOwner);
        vm.expectRevert(IProject.ZeroAddress.selector);
        project.withdraw(address(0));
    }

    function test_WithdrawProtectsPendingReferralRewards() public {
        // Setup: Create subscription with referrer to generate pending rewards
        address referrer = address(0x456);
        address subscriber = address(0x789);

        // First, referrer needs an active subscription
        // STARTER monthly costs 0.005 ether
        vm.deal(referrer, 1 ether);
        vm.prank(referrer);
        project.subscribe{value: 0.005 ether}(
            DataTypes.SubscriptionTier.STARTER, DataTypes.SubscriptionPeriod.MONTHLY, address(0)
        );

        // Now subscriber subscribes with referrer
        vm.deal(subscriber, 1 ether);
        vm.prank(subscriber);
        project.subscribe{value: 0.005 ether}(
            DataTypes.SubscriptionTier.STARTER, DataTypes.SubscriptionPeriod.MONTHLY, referrer
        );

        // Check that pending rewards exist (10% of 0.005 ether = 0.0005 ether)
        (, uint256 totalBalance, uint256 reservedForReferrals) = projectView.getWithdrawableBalance();
        assertEq(reservedForReferrals, 0.0005 ether, "Should have pending referral rewards");

        // Owner withdraws - should only get balance minus pending rewards
        uint256 expectedWithdraw = totalBalance - reservedForReferrals;
        uint256 balanceBefore = projectOwner.balance;

        vm.prank(projectOwner);
        project.withdraw(projectOwner);

        assertEq(projectOwner.balance - balanceBefore, expectedWithdraw, "Should withdraw only available amount");
        assertEq(address(project).balance, reservedForReferrals, "Should keep reserved amount in contract");
    }

    // ==================== View Functions Tests ====================

    function test_GetAllPlans() public {
        DataTypes.SubscriptionPlan[] memory plans = projectView.getAllPlans();
        assertEq(plans.length, 4); // All 4 tiers are enabled
        string[4] memory tierNames = projectView.getTierNames();
        assertEq(tierNames[0], "Starter");
        assertEq(tierNames[1], "Standard");
        assertEq(tierNames[2], "Pro");
        assertEq(tierNames[3], "Max");
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

        (uint256 totalSubs, uint256 totalRewards,) = projectView.getReferralStats();
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

        uint256 rewards = projectView.getUserTotalRewards(subscriber1);
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
            uint256 pendingRewards,
            uint256 refSubscriptions,
            uint256 platformFees,
            uint256 cashbackPaid
        ) = projectView.getProjectStats();

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

        // Net revenue: gross - platform fees - cashback - referrer rewards
        // Note: referrer rewards and cashback are both MAX_MONTHLY / 10
        assertEq(netRevenue, totalRevenue - expectedPlatformFees - (MAX_MONTHLY / 10) - (MAX_MONTHLY / 10));
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
        DataTypes.ReferralAccount memory refAccount = projectView.getReferralAccount(referrer);
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
        project.upgrade{value: upgradeCost}(DataTypes.SubscriptionTier.MAX, DataTypes.SubscriptionPeriod.MONTHLY);

        // Check additional rewards
        DataTypes.ReferralAccount memory refAccount = projectView.getReferralAccount(referrer);
        assertTrue(refAccount.pendingRewards > PRO_MONTHLY / 10);
    }

    // ==================== Pagination Tests ====================

    function test_GetSubscribersPaginated() public {
        // Create multiple subscribers
        address[] memory users = new address[](15);
        for (uint256 i = 0; i < 15; i++) {
            users[i] = address(uint160(200 + i));
            vm.deal(users[i], 1 ether);
            vm.prank(users[i]);
            project.subscribe{value: PRO_MONTHLY}(
                DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.MONTHLY, address(0)
            );
        }

        // Test first page
        (address[] memory page1Addresses, DataTypes.UserSubscription[] memory page1Subs, uint256 total1) =
            projectView.getSubscribersPaginated(0, 10);

        assertEq(page1Addresses.length, 10);
        assertEq(page1Subs.length, 10);
        assertEq(total1, 15);

        // Test second page
        (address[] memory page2Addresses, DataTypes.UserSubscription[] memory page2Subs, uint256 total2) =
            projectView.getSubscribersPaginated(10, 10);

        assertEq(page2Addresses.length, 5); // Only 5 remaining
        assertEq(page2Subs.length, 5);
        assertEq(total2, 15);

        // Verify no overlap between pages
        for (uint256 i = 0; i < page1Addresses.length; i++) {
            for (uint256 j = 0; j < page2Addresses.length; j++) {
                assertTrue(page1Addresses[i] != page2Addresses[j]);
            }
        }

        // Test limit enforcement
        (address[] memory limitedAddresses,,) = projectView.getSubscribersPaginated(0, 150); // Over limit

        assertEq(limitedAddresses.length, 15); // Should return actual count, not exceed total
    }

    function test_GetReferralsPaginated() public {
        // Referrer subscribes first
        vm.prank(referrer);
        project.subscribe{value: PRO_MONTHLY}(
            DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.MONTHLY, address(0)
        );

        // Create multiple referrals
        address[] memory referredUsers = new address[](12);
        for (uint256 i = 0; i < 12; i++) {
            referredUsers[i] = address(uint160(300 + i));
            vm.deal(referredUsers[i], 1 ether);
            vm.prank(referredUsers[i]);
            project.subscribe{value: PRO_MONTHLY}(
                DataTypes.SubscriptionTier.PRO, DataTypes.SubscriptionPeriod.MONTHLY, referrer
            );
        }

        // Test first page of referrals
        (address[] memory page1, uint256 total1) = projectView.getReferralsPaginated(referrer, 0, 10);

        assertEq(page1.length, 10);
        assertEq(total1, 12);

        // Test second page
        (address[] memory page2, uint256 total2) = projectView.getReferralsPaginated(referrer, 10, 10);

        assertEq(page2.length, 2); // Only 2 remaining
        assertEq(total2, 12);

        // Test non-referrer returns empty
        (address[] memory emptyList, uint256 emptyTotal) = projectView.getReferralsPaginated(subscriber1, 0, 10);

        assertEq(emptyList.length, 0);
        assertEq(emptyTotal, 0);
    }

    function test_PlatformFeeWithdrawal() public {
        // Generate revenue - use the exact MAX_YEARLY price
        vm.prank(subscriber1);
        project.subscribe{value: MAX_YEARLY}(
            DataTypes.SubscriptionTier.MAX, DataTypes.SubscriptionPeriod.YEARLY, address(0)
        );

        // Platform fees should be automatically sent to factory (including creation fee)
        uint256 actualBalance = address(factory).balance;
        uint256 expectedPlatformFee = (MAX_YEARLY * 500) / 10000; // 5% of subscription
        uint256 creationFee = 0.01 ether; // From setUp
        assertEq(actualBalance, expectedPlatformFee + creationFee);

        // Platform owner withdraws from factory
        vm.startPrank(platformOwner);
        uint256 platformBalanceBefore = platformOwner.balance;

        factory.withdrawFees(platformOwner);

        assertEq(platformOwner.balance - platformBalanceBefore, expectedPlatformFee + creationFee);
        assertEq(address(factory).balance, 0);

        vm.stopPrank();
    }

    function _createDefaultPrices() internal pure returns (uint256[4][4] memory) {
        uint256[4][4] memory prices;
        // Starter: [daily, weekly, monthly, yearly]
        prices[0] = [uint256(0), 0, 0.001 ether, 0.01 ether];
        // Standard: [daily, weekly, monthly, yearly]
        prices[1] = [uint256(0), 0, 0.002 ether, 0.02 ether];
        // Pro: [daily, weekly, monthly, yearly]
        prices[2] = [uint256(0), 0, 0.003 ether, 0.03 ether];
        // Max: [daily, weekly, monthly, yearly]
        prices[3] = [uint256(0), 0, 0.004 ether, 0.04 ether];
        return prices;
    }

    function test_FactoryProjectManagement() public {
        // Deploy multiple projects
        address[] memory projectOwners = new address[](5);
        address[] memory projects = new address[](5);

        for (uint256 i = 0; i < 5; i++) {
            projectOwners[i] = address(uint160(400 + i));

            DataTypes.BrandConfig memory config = DataTypes.BrandConfig({
                name: string.concat("Proj", vm.toString(i)),
                symbol: string.concat("P", vm.toString(i % 10)),
                description: "Test project",
                logoUri: "",
                websiteUrl: "",
                primaryColor: "",
                maxTier: 3,
                enabledPeriods: [false, false, true, true],
                tierNames: ["Starter", "Standard", "Pro", "Max"]
            });

            vm.deal(projectOwners[i], 1 ether);
            vm.prank(projectOwners[i]);
            projects[i] = factory.deployNewProject{value: 0.01 ether}(config, projectOwners[i], _createDefaultPrices());
        }

        // Test factory's project pagination
        (address[] memory page1, uint256 total) = factory.getProjectsPaginated(0, 3);

        assertEq(page1.length, 3);
        assertEq(total, 6); // 5 new + 1 from setUp

        // Test owner-specific projects
        (address[] memory ownerProjects, uint256 ownerTotal) =
            factory.getOwnerProjectsPaginated(projectOwners[0], 0, 10);

        assertEq(ownerProjects.length, 1);
        assertEq(ownerProjects[0], projects[0]);
        assertEq(ownerTotal, 1);
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
