// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Factory} from "../src/Factory.sol";
import {IFactory} from "../src/interfaces/IFactory.sol";
import {Project} from "../src/Project.sol";
import {DataTypes} from "../src/DataTypes.sol";

contract FactoryTest is Test {
    Factory public factory;
    Project public projectImpl;

    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public attacker = address(0x666);

    // Events
    event ProjectDeployed(
        address indexed project,
        address indexed owner,
        string name,
        string symbol,
        uint256 timestamp
    );
    event CreationFeeUpdated(uint256 oldFee, uint256 newFee);
    event ImplementationUpdated(
        address oldImplementation,
        address newImplementation
    );
    event PlatformFeeUpdated(uint256 oldBasisPoints, uint256 newBasisPoints);

    function setUp() public {
        vm.startPrank(owner);
        projectImpl = new Project();
        factory = new Factory(owner, address(projectImpl));
        vm.stopPrank();

        // Fund test accounts
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(attacker, 10 ether);
    }

    // ============ Constructor Tests ============

    function test_Constructor_Success() public {
        Factory newFactory = new Factory(owner, address(projectImpl));
        assertEq(newFactory.owner(), owner);
        assertEq(newFactory.projectImplementation(), address(projectImpl));
        assertEq(newFactory.projectCreationFee(), 0.01 ether);
        assertEq(newFactory.platformFeeBasisPoints(), 500);
    }

    function test_Constructor_RevertZeroOwner() public {
        vm.expectRevert(IFactory.ZeroAddress.selector);
        new Factory(address(0), address(projectImpl));
    }

    function test_Constructor_RevertZeroImplementation() public {
        vm.expectRevert(IFactory.ZeroAddress.selector);
        new Factory(owner, address(0));
    }

    // ============ deployNewProject Tests ============

    function test_DeployNewProject_Success() public {
        DataTypes.BrandConfig memory config = _createBrandConfig(
            "Test Project",
            "TEST"
        );

        vm.startPrank(user1);
        // Note: We don't know the exact project address before deployment, so we check other params
        vm.expectEmit(false, true, false, false);
        emit ProjectDeployed(
            address(0),
            user1,
            "Test Project",
            "TEST",
            block.timestamp
        );

        address project = factory.deployNewProject{value: 0.01 ether}(
            config,
            user1,
            _createDefaultPrices()
        );
        vm.stopPrank();

        // Verify project data
        assertEq(factory.projectToOwner(project), user1);
        assertEq(factory.getTotalProjects(), 1);
        assertEq(factory.getOwnerProjectCount(user1), 1);

        // Verify salt mapping
        bytes32 salt = keccak256(abi.encodePacked("Test Project", "TEST"));
        assertEq(factory.saltToProject(salt), project);

        // Verify project exists check
        (bool exists, address existingProject) = factory.isProjectNameTaken(
            "Test Project",
            "TEST"
        );
        assertTrue(exists);
        assertEq(existingProject, project);
    }

    function test_DeployNewProject_DifferentOwner() public {
        DataTypes.BrandConfig memory config = _createBrandConfig("Test", "TST");

        vm.prank(user1);
        address project = factory.deployNewProject{value: 0.01 ether}(
            config,
            user2,
            _createDefaultPrices()
        );

        assertEq(factory.projectToOwner(project), user2);
        assertEq(factory.getOwnerProjectCount(user2), 1);
        assertEq(factory.getOwnerProjectCount(user1), 0);
    }

    function test_DeployNewProject_RevertInsufficientFee() public {
        DataTypes.BrandConfig memory config = _createBrandConfig("Test", "TST");

        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IFactory.InvalidFee.selector,
                0.005 ether,
                0.01 ether
            )
        );
        factory.deployNewProject{value: 0.005 ether}(
            config,
            user1,
            _createDefaultPrices()
        );
        vm.stopPrank();
    }

    function test_DeployNewProject_RevertExcessFee() public {
        DataTypes.BrandConfig memory config = _createBrandConfig("Test", "TST");

        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IFactory.InvalidFee.selector,
                0.02 ether,
                0.01 ether
            )
        );
        factory.deployNewProject{value: 0.02 ether}(
            config,
            user1,
            _createDefaultPrices()
        );
        vm.stopPrank();
    }

    function test_DeployNewProject_RevertZeroOwner() public {
        DataTypes.BrandConfig memory config = _createBrandConfig("Test", "TST");

        vm.startPrank(user1);
        vm.expectRevert(IFactory.ZeroAddress.selector);
        factory.deployNewProject{value: 0.01 ether}(
            config,
            address(0),
            _createDefaultPrices()
        );
        vm.stopPrank();
    }

    function test_DeployNewProject_RevertEmptyName() public {
        DataTypes.BrandConfig memory config = _createBrandConfig("", "TST");

        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IFactory.InvalidInput.selector,
                "Project name cannot be empty"
            )
        );
        factory.deployNewProject{value: 0.01 ether}(
            config,
            user1,
            _createDefaultPrices()
        );
        vm.stopPrank();
    }

    function test_DeployNewProject_RevertEmptySymbol() public {
        DataTypes.BrandConfig memory config = _createBrandConfig("Test", "");

        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IFactory.InvalidInput.selector,
                "Project symbol cannot be empty"
            )
        );
        factory.deployNewProject{value: 0.01 ether}(
            config,
            user1,
            _createDefaultPrices()
        );
        vm.stopPrank();
    }

    function test_DeployNewProject_RevertNameTooLong() public {
        string memory longName = _generateString(101);
        DataTypes.BrandConfig memory config = _createBrandConfig(
            longName,
            "TST"
        );

        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IFactory.InvalidInput.selector,
                "Project name too long"
            )
        );
        factory.deployNewProject{value: 0.01 ether}(
            config,
            user1,
            _createDefaultPrices()
        );
        vm.stopPrank();
    }

    function test_DeployNewProject_RevertSymbolTooLong() public {
        string memory longSymbol = _generateString(21);
        DataTypes.BrandConfig memory config = _createBrandConfig(
            "Test",
            longSymbol
        );

        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IFactory.InvalidInput.selector,
                "Project symbol too long"
            )
        );
        factory.deployNewProject{value: 0.01 ether}(
            config,
            user1,
            _createDefaultPrices()
        );
        vm.stopPrank();
    }

    function test_DeployNewProject_RevertProjectAlreadyExists() public {
        DataTypes.BrandConfig memory config = _createBrandConfig("Test", "TST");

        vm.startPrank(user1);
        address firstProject = factory.deployNewProject{value: 0.01 ether}(
            config,
            user1,
            _createDefaultPrices()
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IFactory.ProjectAlreadyExists.selector,
                firstProject
            )
        );
        factory.deployNewProject{value: 0.01 ether}(
            config,
            user2,
            _createDefaultPrices()
        );
        vm.stopPrank();
    }

    function test_DeployNewProject_MultipleProjects() public {
        vm.startPrank(user1);

        for (uint256 i = 0; i < 5; i++) {
            DataTypes.BrandConfig memory config = _createBrandConfig(
                string(abi.encodePacked("Project", vm.toString(i))),
                string(abi.encodePacked("P", vm.toString(i)))
            );
            factory.deployNewProject{value: 0.01 ether}(
                config,
                user1,
                _createDefaultPrices()
            );
        }

        vm.stopPrank();

        assertEq(factory.getTotalProjects(), 5);
        assertEq(factory.getOwnerProjectCount(user1), 5);
    }

    // ============ Setter Function Tests ============

    function test_SetProjectCreationFee_Success() public {
        uint256 newFee = 0.05 ether;

        vm.startPrank(owner);
        vm.expectEmit(true, true, false, true);
        emit CreationFeeUpdated(0.01 ether, newFee);

        factory.setProjectCreationFee(newFee);
        vm.stopPrank();

        assertEq(factory.projectCreationFee(), newFee);
    }

    function test_SetProjectCreationFee_OnlyOwner() public {
        vm.startPrank(user1);
        vm.expectRevert(); // Ownable revert
        factory.setProjectCreationFee(0.05 ether);
        vm.stopPrank();
    }

    function test_SetProjectCreationFee_Zero() public {
        vm.prank(owner);
        factory.setProjectCreationFee(0);
        assertEq(factory.projectCreationFee(), 0);
    }

    function test_SetProjectImplementation_Success() public {
        address newImpl = address(new Project());

        vm.startPrank(owner);
        vm.expectEmit(true, true, false, true);
        emit ImplementationUpdated(address(projectImpl), newImpl);

        factory.setProjectImplementation(newImpl);
        vm.stopPrank();

        assertEq(factory.projectImplementation(), newImpl);
    }

    function test_SetProjectImplementation_RevertZeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert(IFactory.ZeroAddress.selector);
        factory.setProjectImplementation(address(0));
        vm.stopPrank();
    }

    function test_SetProjectImplementation_OnlyOwner() public {
        address newImpl = address(new Project());
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        factory.setProjectImplementation(newImpl);
        vm.stopPrank();
    }

    function test_SetPlatformFeeBasisPoints_Success() public {
        uint256 newBasisPoints = 250; // 2.5%

        vm.startPrank(owner);
        vm.expectEmit(true, true, false, true);
        emit PlatformFeeUpdated(500, newBasisPoints);

        factory.setPlatformFeeBasisPoints(newBasisPoints);
        vm.stopPrank();

        assertEq(factory.platformFeeBasisPoints(), newBasisPoints);
    }

    function test_SetPlatformFeeBasisPoints_Maximum() public {
        vm.prank(owner);
        factory.setPlatformFeeBasisPoints(3000); // 30%
        assertEq(factory.platformFeeBasisPoints(), 3000);
    }

    function test_SetPlatformFeeBasisPoints_RevertExceedsMaximum() public {
        vm.startPrank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(IFactory.InvalidBasisPoints.selector, 10001)
        );
        factory.setPlatformFeeBasisPoints(10001);
        vm.stopPrank();
    }

    function test_SetPlatformFeeBasisPoints_OnlyOwner() public {
        vm.startPrank(user1);
        vm.expectRevert(); // Ownable revert
        factory.setPlatformFeeBasisPoints(250);
        vm.stopPrank();
    }

    // ============ View Function Tests ============

    function test_GetProjectsPaginated() public {
        // Deploy 10 projects
        _deployMultipleProjects(10);

        // Test first page
        (address[] memory projects1, uint256 total1) = factory
            .getProjectsPaginated(0, 5);
        assertEq(projects1.length, 5);
        assertEq(total1, 10);

        // Test second page
        (address[] memory projects2, uint256 total2) = factory
            .getProjectsPaginated(5, 5);
        assertEq(projects2.length, 5);
        assertEq(total2, 10);

        // Test with limit exceeding remaining
        (address[] memory projects3, uint256 total3) = factory
            .getProjectsPaginated(8, 5);
        assertEq(projects3.length, 2);
        assertEq(total3, 10);

        // Test offset out of bounds
        (address[] memory projects4, uint256 total4) = factory
            .getProjectsPaginated(15, 5);
        assertEq(projects4.length, 0);
        assertEq(total4, 10);
    }

    function test_GetProjectsPaginated_MaxLimit() public {
        _deployMultipleProjects(150);

        // Test that limit is capped at 100
        (address[] memory projects, ) = factory.getProjectsPaginated(0, 200);
        assertEq(projects.length, 100);
    }

    function test_GetOwnerProjectsPaginated() public {
        // Deploy projects for different users
        vm.startPrank(user1);
        for (uint256 i = 0; i < 5; i++) {
            DataTypes.BrandConfig memory config = _createBrandConfig(
                string(abi.encodePacked("User1Project", vm.toString(i))),
                string(abi.encodePacked("U1P", vm.toString(i)))
            );
            factory.deployNewProject{value: 0.01 ether}(
                config,
                user1,
                _createDefaultPrices()
            );
        }
        vm.stopPrank();

        vm.startPrank(user2);
        for (uint256 i = 0; i < 3; i++) {
            DataTypes.BrandConfig memory config = _createBrandConfig(
                string(abi.encodePacked("User2Project", vm.toString(i))),
                string(abi.encodePacked("U2P", vm.toString(i)))
            );
            factory.deployNewProject{value: 0.01 ether}(
                config,
                user2,
                _createDefaultPrices()
            );
        }
        vm.stopPrank();

        // Test user1's projects
        (address[] memory user1Projects, uint256 user1Total) = factory
            .getOwnerProjectsPaginated(user1, 0, 10);
        assertEq(user1Projects.length, 5);
        assertEq(user1Total, 5);

        // Test user2's projects
        (address[] memory user2Projects, uint256 user2Total) = factory
            .getOwnerProjectsPaginated(user2, 0, 10);
        assertEq(user2Projects.length, 3);
        assertEq(user2Total, 3);

        // Test pagination for user1
        (address[] memory user1Page1, ) = factory.getOwnerProjectsPaginated(
            user1,
            0,
            3
        );
        assertEq(user1Page1.length, 3);

        (address[] memory user1Page2, ) = factory.getOwnerProjectsPaginated(
            user1,
            3,
            3
        );
        assertEq(user1Page2.length, 2);
    }

    function test_CalculatePlatformFee() public view {
        uint256 amount = 1000 ether;
        uint256 expectedFee = (amount * 500) / 10000; // 5%
        uint256 calculatedFee = factory.calculatePlatformFee(amount);

        assertEq(calculatedFee, expectedFee);
        assertEq(calculatedFee, 50 ether);
    }

    function test_CalculatePlatformFee_DifferentBasisPoints() public {
        vm.prank(owner);
        factory.setPlatformFeeBasisPoints(250); // 2.5%

        uint256 amount = 1000 ether;
        uint256 expectedFee = (amount * 250) / 10000;
        uint256 calculatedFee = factory.calculatePlatformFee(amount);

        assertEq(calculatedFee, expectedFee);
        assertEq(calculatedFee, 25 ether);
    }

    function test_CalculatePlatformFee_Zero() public {
        vm.prank(owner);
        factory.setPlatformFeeBasisPoints(0);

        uint256 calculatedFee = factory.calculatePlatformFee(1000 ether);
        assertEq(calculatedFee, 0);
    }

    function test_GetTotalProjects() public {
        assertEq(factory.getTotalProjects(), 0);

        _deployMultipleProjects(5);
        assertEq(factory.getTotalProjects(), 5);

        // Deploy 3 more with different names to avoid duplicates
        for (uint256 i = 100; i < 103; i++) {
            DataTypes.BrandConfig memory config = _createBrandConfig(
                string(abi.encodePacked("Additional", vm.toString(i))),
                string(abi.encodePacked("ADD", vm.toString(i)))
            );
            vm.prank(user1);
            factory.deployNewProject{value: 0.01 ether}(
                config,
                user1,
                _createDefaultPrices()
            );
        }
        assertEq(factory.getTotalProjects(), 8);
    }

    function test_GetOwnerProjectCount() public {
        assertEq(factory.getOwnerProjectCount(user1), 0);

        vm.startPrank(user1);
        DataTypes.BrandConfig memory config = _createBrandConfig("Test", "TST");
        factory.deployNewProject{value: 0.01 ether}(
            config,
            user1,
            _createDefaultPrices()
        );
        vm.stopPrank();

        assertEq(factory.getOwnerProjectCount(user1), 1);
    }

    function test_IsProjectNameTaken() public {
        (bool exists1, address project1) = factory.isProjectNameTaken(
            "Test",
            "TST"
        );
        assertFalse(exists1);
        assertEq(project1, address(0));

        vm.startPrank(user1);
        DataTypes.BrandConfig memory config = _createBrandConfig("Test", "TST");
        address deployedProject = factory.deployNewProject{value: 0.01 ether}(
            config,
            user1,
            _createDefaultPrices()
        );
        vm.stopPrank();

        (bool exists2, address project2) = factory.isProjectNameTaken(
            "Test",
            "TST"
        );
        assertTrue(exists2);
        assertEq(project2, deployedProject);
    }

    // ============ withdrawFees Tests ============

    function test_WithdrawFees_Success() public {
        // Deploy projects to accumulate fees
        _deployMultipleProjects(5);

        uint256 expectedBalance = 0.05 ether; // 5 * 0.01 ether
        assertEq(address(factory).balance, expectedBalance);

        address recipient = address(0x99);
        uint256 recipientBalanceBefore = recipient.balance;

        vm.prank(owner);
        factory.withdrawFees(recipient);

        assertEq(address(factory).balance, 0);
        assertEq(recipient.balance, recipientBalanceBefore + expectedBalance);
    }

    function test_WithdrawFees_OnlyOwner() public {
        _deployMultipleProjects(1);

        vm.startPrank(user1);
        vm.expectRevert(); // Ownable revert
        factory.withdrawFees(user1);
        vm.stopPrank();
    }

    function test_WithdrawFees_RevertZeroAddress() public {
        _deployMultipleProjects(1);

        vm.startPrank(owner);
        vm.expectRevert(IFactory.ZeroAddress.selector);
        factory.withdrawFees(address(0));
        vm.stopPrank();
    }

    function test_WithdrawFees_RevertNoFees() public {
        vm.startPrank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IFactory.InvalidInput.selector,
                "No fees to withdraw"
            )
        );
        factory.withdrawFees(owner);
        vm.stopPrank();
    }

    // ============ Security Tests ============

    function test_ReentrancyProtection_WithdrawFees() public {
        // Test that reentrancy is prevented in withdrawFees
        // When a malicious receiver tries to reenter, the transaction should fail

        // Deploy a project to generate fees
        DataTypes.BrandConfig memory config = _createBrandConfig("Test", "TST");
        vm.prank(user1);
        factory.deployNewProject{value: 0.01 ether}(
            config,
            user1,
            _createDefaultPrices()
        );

        // Create malicious owner contract
        MaliciousOwner maliciousOwner = new MaliciousOwner(address(factory));

        // Transfer ownership to malicious contract
        vm.prank(owner);
        factory.transferOwnership(address(maliciousOwner));

        // The malicious owner will try to reenter, but the outer call fails with TransferFailed
        // because the inner reentrant call reverts with Reentrancy, causing the transfer to fail
        vm.expectRevert(IFactory.TransferFailed.selector);
        maliciousOwner.attackWithdraw();

        // Verify that the reentrancy was indeed blocked (funds still in factory)
        assertEq(address(factory).balance, 0.01 ether);
    }

    function test_ReceiveFunction() public {
        uint256 balanceBefore = address(factory).balance;

        vm.prank(user1);
        (bool success, ) = address(factory).call{value: 1 ether}("");
        assertTrue(success);

        assertEq(address(factory).balance, balanceBefore + 1 ether);
    }

    // ============ Constant Tests ============

    function test_Constants() public view {
        assertEq(factory.MAX_BASIS_POINTS(), 10000);
        assertEq(factory.MAX_PAGINATION_LIMIT(), 100);
    }

    // ============ Helper Functions ============

    function _createBrandConfig(
        string memory name,
        string memory symbol
    ) internal pure returns (DataTypes.BrandConfig memory) {
        return
            DataTypes.BrandConfig({
                name: name,
                symbol: symbol,
                description: "Test project description",
                logoUri: "https://example.com/logo.png",
                websiteUrl: "https://example.com",
                primaryColor: "#FF0000",
                maxTier: 1, // Enable STARTER and STANDARD tiers (0-1)
                enabledPeriods: [false, false, true, true], // Enable monthly and yearly only
                tierNames: ["Starter", "Standard", "Pro", "Max"] // Default tier names
            });
    }

    function _createDefaultPrices()
        internal
        pure
        returns (uint256[4][4] memory)
    {
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

    function _generateString(
        uint256 length
    ) internal pure returns (string memory) {
        bytes memory result = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            result[i] = bytes1(uint8(65 + (i % 26))); // A-Z
        }
        return string(result);
    }

    function _deployMultipleProjects(uint256 count) internal {
        for (uint256 i = 0; i < count; i++) {
            DataTypes.BrandConfig memory config = _createBrandConfig(
                string(
                    abi.encodePacked(
                        "Project",
                        vm.toString(block.timestamp + i)
                    )
                ),
                string(abi.encodePacked("P", vm.toString(block.timestamp + i)))
            );
            vm.prank(user1);
            factory.deployNewProject{value: 0.01 ether}(
                config,
                user1,
                _createDefaultPrices()
            );
        }
    }
}

// ============ Attack Contracts ============

contract MaliciousOwner {
    Factory public factory;
    bool attacking;

    constructor(address _factory) {
        factory = Factory(payable(_factory));
    }

    function attackWithdraw() external {
        attacking = true;
        factory.withdrawFees(address(this));
    }

    receive() external payable {
        // When receiving funds, try to call withdrawFees again
        if (attacking && msg.sender == address(factory)) {
            attacking = false; // Prevent infinite loop in test
            factory.withdrawFees(address(this)); // This should revert with Reentrancy
        }
    }

    // Implement Ownable interface
    function owner() external view returns (address) {
        return address(this);
    }

    function transferOwnership(address newOwner) external {
        // Do nothing
    }

    function renounceOwnership() external {
        // Do nothing
    }
}

contract ReentrantAttacker {
    Factory public factory;
    bool public attacking;

    constructor(address _factory) {
        factory = Factory(payable(_factory));
    }

    function _createDefaultPrices()
        internal
        pure
        returns (uint256[4][4] memory)
    {
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

    function attack() external {
        attacking = true;
        DataTypes.BrandConfig memory config = DataTypes.BrandConfig({
            name: "Attack",
            symbol: "ATK",
            description: "",
            logoUri: "",
            websiteUrl: "",
            primaryColor: "",
            maxTier: 1,
            enabledPeriods: [false, false, true, true],
            tierNames: ["Starter", "Standard", "Pro", "Max"]
        });
        factory.deployNewProject{value: 0.01 ether}(
            config,
            address(this),
            _createDefaultPrices()
        );
    }

    receive() external payable {
        if (attacking) {
            attacking = false;
            DataTypes.BrandConfig memory config = DataTypes.BrandConfig({
                name: "Attack2",
                symbol: "ATK2",
                description: "",
                logoUri: "",
                websiteUrl: "",
                primaryColor: "",
                maxTier: 1,
                enabledPeriods: [false, false, true, true],
                tierNames: ["Starter", "Standard", "Pro", "Max"]
            });
            factory.deployNewProject{value: 0.01 ether}(
                config,
                address(this),
                _createDefaultPrices()
            );
        }
    }
}
