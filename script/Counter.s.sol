// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {Factory} from "../src/Factory.sol";

contract FactoryScript is Script {
    Factory public factory;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();


        // factory = new Factory();

        vm.stopBroadcast();
    }
}
