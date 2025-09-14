// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Ownable} from "solady/auth/Ownable.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {DataTypes} from "./DataTypes.sol";
import {IFactory} from "./interfaces/IFactory.sol";
import {ProjectReaderImpl} from "./ProjectReaderImpl.sol";

interface IProject {
    function initialize(
        DataTypes.BrandConfig memory _brandConfig,
        address _factory,
        address _owner,
        uint256[4][4] memory prices
    ) external;
}

contract Factory is IFactory, Ownable, ReentrancyGuard {
    using LibClone for address;

    // Constants
    uint256 public constant MAX_BASIS_POINTS = 10000;
    uint256 public constant MAX_PAGINATION_LIMIT = 100;
    uint256 public constant MAX_PLATFORM_FEE_BASIS_POINTS = 3000; // 30% max platform fee

    // Core configuration
    address public projectImplementation;
    address public projectReaderImplementation; // Shared reader implementation for all projects
    uint256 public projectCreationFee = 0.01 ether;
    uint256 public platformFeeBasisPoints = 500; // 500 basis points = 5%

    // Tracking deployed projects
    address[] public projects;
    mapping(address => address[]) public ownerProjects;
    mapping(address => address) public projectToOwner; // project => owner mapping
    mapping(bytes32 => address) public saltToProject; // salt => project address for lookup

    // Revenue tracking
    uint256 public totalCreationFeesCollected; // Total fees from deployNewProject
    uint256 public totalPlatformFeesReceived; // Total platform fees from projects
    uint256 public totalDirectDeposits; // Total ETH sent directly via receive()

    // Events and Errors are defined in IFactory interface

    /**
     * @notice Receive function to accept ETH (platform fees from projects and direct deposits)
     */
    receive() external payable {
        // Check if sender is a deployed project (platform fee) or external (direct deposit)
        if (projectToOwner[msg.sender] != address(0)) {
            // This is a platform fee from a project
            totalPlatformFeesReceived += msg.value;
        } else {
            // This is a direct deposit
            totalDirectDeposits += msg.value;
        }
    }

    /**
     * @notice Constructor to initialize the factory contract
     * @param owner_ Address of the factory owner
     * @param projectImplementation_ Address of the project implementation contract to clone
     */
    constructor(address owner_, address projectImplementation_) {
        if (owner_ == address(0)) revert ZeroAddress();
        if (projectImplementation_ == address(0)) revert ZeroAddress();
        _initializeOwner(owner_);
        projectImplementation = projectImplementation_;

        // Deploy the shared ProjectReaderImpl once for all projects
        projectReaderImplementation = address(new ProjectReaderImpl());
    }

    // View functions
    /**
     * @notice Get all deployed projects with pagination
     * @param offset Starting index for pagination
     * @param limit Maximum number of projects to return (capped at 100)
     * @return projectList Array of project addresses
     * @return totalCount Total number of projects in the system
     */
    function getProjectsPaginated(uint256 offset, uint256 limit)
        external
        view
        returns (address[] memory projectList, uint256 totalCount)
    {
        totalCount = projects.length;

        // Early return if offset is out of bounds
        if (offset >= totalCount) {
            return (new address[](0), totalCount);
        }

        // Cap limit to prevent excessive gas usage
        if (limit > MAX_PAGINATION_LIMIT) {
            limit = MAX_PAGINATION_LIMIT;
        }

        // Calculate actual items to return
        uint256 remaining = totalCount - offset;
        uint256 returnCount = remaining < limit ? remaining : limit;

        // Create return array and populate
        projectList = new address[](returnCount);
        unchecked {
            for (uint256 i; i < returnCount; ++i) {
                projectList[i] = projects[offset + i];
            }
        }
    }

    /**
     * @notice Get projects owned by a specific address with pagination
     * @param owner Address of the project owner to query
     * @param offset Starting index for pagination
     * @param limit Maximum number of projects to return (capped at 100)
     * @return projectList Array of project addresses owned by the specified owner
     * @return totalCount Total number of projects owned by this address
     */
    function getOwnerProjectsPaginated(address owner, uint256 offset, uint256 limit)
        external
        view
        returns (address[] memory projectList, uint256 totalCount)
    {
        address[] storage userProjects = ownerProjects[owner];
        totalCount = userProjects.length;

        // Early return if offset is out of bounds
        if (offset >= totalCount) {
            return (new address[](0), totalCount);
        }

        // Cap limit to prevent excessive gas usage
        if (limit > MAX_PAGINATION_LIMIT) {
            limit = MAX_PAGINATION_LIMIT;
        }

        // Calculate actual items to return
        uint256 remaining = totalCount - offset;
        uint256 returnCount = remaining < limit ? remaining : limit;

        // Create return array and populate
        projectList = new address[](returnCount);
        unchecked {
            for (uint256 i; i < returnCount; ++i) {
                projectList[i] = userProjects[offset + i];
            }
        }
    }

    /**
     * @notice Set the fee required to create a new project
     * @param newFee The new creation fee amount in wei
     */
    function setProjectCreationFee(uint256 newFee) external onlyOwner {
        uint256 oldFee = projectCreationFee;
        projectCreationFee = newFee;
        emit CreationFeeUpdated(oldFee, newFee);
    }

    /**
     * @notice Update the project implementation contract address
     * @param newImplementation Address of the new implementation contract
     */
    function setProjectImplementation(address newImplementation) external onlyOwner {
        if (newImplementation == address(0)) revert ZeroAddress();
        address oldImplementation = projectImplementation;
        projectImplementation = newImplementation;
        emit ImplementationUpdated(oldImplementation, newImplementation);
    }

    /**
     * @notice Set the platform fee in basis points
     * @param newBasisPoints The new platform fee in basis points (e.g., 500 for 5%)
     * @dev 1 basis point = 0.01%, maximum allowed is 3000 (30%) to maintain project attractiveness
     */
    function setPlatformFeeBasisPoints(uint256 newBasisPoints) external onlyOwner {
        if (newBasisPoints > MAX_PLATFORM_FEE_BASIS_POINTS) {
            revert InvalidBasisPoints(newBasisPoints);
        }
        uint256 oldBasisPoints = platformFeeBasisPoints;
        platformFeeBasisPoints = newBasisPoints;
        emit PlatformFeeUpdated(oldBasisPoints, newBasisPoints);
    }

    /**
     * @notice Deploy a new project by cloning the implementation contract
     * @param brandConfig Configuration for the project brand including name, symbol, etc.
     * @param projectOwner Address that will own the deployed project
     * @return project Address of the newly deployed project contract
     */
    function deployNewProject(
        DataTypes.BrandConfig memory brandConfig,
        address projectOwner,
        uint256[4][4] memory prices
    ) external payable nonReentrant returns (address project) {
        if (msg.value != projectCreationFee) {
            revert InvalidFee(msg.value, projectCreationFee);
        }

        // Track creation fee
        totalCreationFeesCollected += msg.value;

        if (projectOwner == address(0)) revert ZeroAddress();
        // Validate brand config
        if (bytes(brandConfig.name).length == 0) {
            revert InvalidInput("Project name cannot be empty");
        }
        if (bytes(brandConfig.symbol).length == 0) {
            revert InvalidInput("Project symbol cannot be empty");
        }
        // Add length limits to prevent DOS
        if (bytes(brandConfig.name).length > 100) {
            revert InvalidInput("Project name too long");
        }
        if (bytes(brandConfig.symbol).length > 20) {
            revert InvalidInput("Project symbol too long");
        }

        // Generate salt using standard Solidity (simpler and cleaner)
        bytes32 salt = keccak256(abi.encodePacked(brandConfig.name, brandConfig.symbol));

        // Check if project already exists with this salt
        if (saltToProject[salt] != address(0)) {
            revert ProjectAlreadyExists(saltToProject[salt]);
        }

        project = projectImplementation.cloneDeterministic(salt);
        IProject(project).initialize(brandConfig, address(this), projectOwner, prices);

        // Store project data
        projects.push(project);
        ownerProjects[projectOwner].push(project);
        projectToOwner[project] = projectOwner;
        saltToProject[salt] = project;

        // Fees remain in the contract and can be withdrawn using withdrawFees()

        emit ProjectDeployed(project, projectOwner, brandConfig.name, brandConfig.symbol, block.timestamp);
    }

    /**
     * @notice Withdraw accumulated fees from the factory
     * @param recipient Address to receive the withdrawn fees
     */
    function withdrawFees(address recipient) external onlyOwner nonReentrant {
        if (recipient == address(0)) revert ZeroAddress();
        uint256 balance = address(this).balance;
        if (balance == 0) revert InvalidInput("No fees to withdraw");

        (bool success,) = payable(recipient).call{value: balance}("");
        if (!success) revert TransferFailed();
    }

    /**
     * @notice Calculate platform fee for a given amount
     * @param amount The amount to calculate fee for
     * @return fee The calculated platform fee
     */
    function calculatePlatformFee(uint256 amount) public view returns (uint256 fee) {
        fee = (amount * platformFeeBasisPoints) / MAX_BASIS_POINTS;
    }

    /**
     * @notice Get comprehensive factory revenue statistics
     * @return creationFees Total fees from project creation
     * @return platformFees Total platform fees received from projects
     * @return directDeposits Total direct ETH deposits
     * @return totalBalance Current contract balance
     */
    function getRevenueStats()
        external
        view
        returns (uint256 creationFees, uint256 platformFees, uint256 directDeposits, uint256 totalBalance)
    {
        return (totalCreationFeesCollected, totalPlatformFeesReceived, totalDirectDeposits, address(this).balance);
    }

    /**
     * @notice Get total number of projects deployed
     * @return Total number of projects
     */
    function getTotalProjects() external view returns (uint256) {
        return projects.length;
    }

    /**
     * @notice Get total number of projects owned by an address
     * @param owner Address to query
     * @return Total number of projects owned
     */
    function getOwnerProjectCount(address owner) external view returns (uint256) {
        return ownerProjects[owner].length;
    }

    /**
     * @notice Check if a project name and symbol combination is already taken
     * @param name Project name
     * @param symbol Project symbol
     * @return exists True if the combination already exists
     * @return existingProject Address of existing project if it exists
     */
    function isProjectNameTaken(string memory name, string memory symbol)
        external
        view
        returns (bool exists, address existingProject)
    {
        bytes32 salt = keccak256(abi.encodePacked(name, symbol));
        existingProject = saltToProject[salt];
        exists = existingProject != address(0);
    }

    // Disabled functions
    function requestOwnershipHandover() public payable override {
        revert("This function is disabled");
    }

    function cancelOwnershipHandover() public payable override {
        revert("This function is disabled");
    }

    function completeOwnershipHandover(address /* pendingOwner */ ) public payable override onlyOwner {
        revert("This function is disabled");
    }

    function ownershipHandoverExpiresAt(address /* pendingOwner */ ) public view override returns (uint256 result) {
        result = totalDirectDeposits;
        revert("This function is disabled");
    }

    function renounceOwnership() public payable override onlyOwner {
        revert("This function is disabled");
    }
}
