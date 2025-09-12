// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {DataTypes} from "../DataTypes.sol";

/**
 * @title IFactory
 * @notice Interface for the Factory contract that deploys projects using clone pattern
 */
interface IFactory {
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

    // Errors
    error InvalidFee(uint256 sent, uint256 required);
    error InvalidInput(string reason);
    error ZeroAddress();
    error InvalidBasisPoints(uint256 basisPoints);
    error TransferFailed();
    error ProjectAlreadyExists(address existingProject);

    // Note: Reentrancy error is inherited from Solady's ReentrancyGuard

    // View Functions
    function projectImplementation() external view returns (address);

    function projectCreationFee() external view returns (uint256);

    function platformFeeBasisPoints() external view returns (uint256);

    function projects(uint256 index) external view returns (address);

    function ownerProjects(
        address owner,
        uint256 index
    ) external view returns (address);

    function projectToOwner(address project) external view returns (address);

    function saltToProject(bytes32 salt) external view returns (address);

    function MAX_BASIS_POINTS() external view returns (uint256);

    function MAX_PAGINATION_LIMIT() external view returns (uint256);

    // Revenue tracking
    function totalCreationFeesCollected() external view returns (uint256);

    function totalPlatformFeesReceived() external view returns (uint256);

    function totalDirectDeposits() external view returns (uint256);

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
        returns (
            uint256 creationFees,
            uint256 platformFees,
            uint256 directDeposits,
            uint256 totalBalance
        );

    /**
     * @notice Get all deployed projects with pagination
     * @param offset Starting index for pagination
     * @param limit Maximum number of projects to return (capped at 100)
     * @return projectList Array of project addresses
     * @return totalCount Total number of projects in the system
     */
    function getProjectsPaginated(
        uint256 offset,
        uint256 limit
    ) external view returns (address[] memory projectList, uint256 totalCount);

    /**
     * @notice Get projects owned by a specific address with pagination
     * @param owner Address of the project owner to query
     * @param offset Starting index for pagination
     * @param limit Maximum number of projects to return (capped at 100)
     * @return projectList Array of project addresses owned by the specified owner
     * @return totalCount Total number of projects owned by this address
     */
    function getOwnerProjectsPaginated(
        address owner,
        uint256 offset,
        uint256 limit
    ) external view returns (address[] memory projectList, uint256 totalCount);

    /**
     * @notice Calculate platform fee for a given amount
     * @param amount The amount to calculate fee for
     * @return fee The calculated platform fee
     */
    function calculatePlatformFee(
        uint256 amount
    ) external view returns (uint256 fee);

    /**
     * @notice Get total number of projects deployed
     * @return Total number of projects
     */
    function getTotalProjects() external view returns (uint256);

    /**
     * @notice Get total number of projects owned by an address
     * @param owner Address to query
     * @return Total number of projects owned
     */
    function getOwnerProjectCount(
        address owner
    ) external view returns (uint256);

    /**
     * @notice Check if a project name and symbol combination is already taken
     * @param name Project name
     * @param symbol Project symbol
     * @return exists True if the combination already exists
     * @return existingProject Address of existing project if it exists
     */
    function isProjectNameTaken(
        string memory name,
        string memory symbol
    ) external view returns (bool exists, address existingProject);

    // State-Changing Functions

    /**
     * @notice Set the fee required to create a new project
     * @param newFee The new creation fee amount in wei
     */
    function setProjectCreationFee(uint256 newFee) external;

    /**
     * @notice Update the project implementation contract address
     * @param newImplementation Address of the new implementation contract
     */
    function setProjectImplementation(address newImplementation) external;

    /**
     * @notice Set the platform fee in basis points
     * @param newBasisPoints The new platform fee in basis points (e.g., 500 for 5%)
     */
    function setPlatformFeeBasisPoints(uint256 newBasisPoints) external;

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
    ) external payable returns (address project);

    /**
     * @notice Withdraw accumulated fees from the factory
     * @param recipient Address to receive the withdrawn fees
     */
    function withdrawFees(address recipient) external;
}
