// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import {DataTypes} from "./DataTypes.sol";
import {ProjectStorage} from "./ProjectStorage.sol";

contract Project is ProjectStorage {
    function initialize(
        DataTypes.BrandConfig memory _brandConfig,
        address _factory,
        address _owner
    ) external {
        require(!initialized, "Already initialized");
        initialized = true;
        brandConfig = _brandConfig;
        factory = _factory;
        _initializeOwner(_owner);
    }
}
