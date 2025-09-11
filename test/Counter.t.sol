// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Factory} from "../src/Factory.sol";

contract FactoryTest is Test {
    Factory public factory;

    // function setUp() public {
    //     factory = new Factory();
    //     factory.setNumber(0);
    // }

    // function test_Increment() public {
    //     factory.increment();
    //     assertEq(factory.number(), 1);
    // }

    // function testFuzz_SetNumber(uint256 x) public {
    //     factory.setNumber(x);
    //     assertEq(factory.number(), x);
    // }
}
