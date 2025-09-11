// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {Ownable} from "solady/auth/Ownable.sol";
import {DataTypes} from "./DataTypes.sol";

contract ProjectStorage is Ownable{
    // ========== 版本（Edition）存储 ==========
    uint256 public currentEditionId;
    uint256 public nextEditionId = 1;
    mapping(uint256 => DataTypes.Edition) public editions;
    mapping(uint256 => DataTypes.EditionStats) public editionStats;

    // ========== 订阅（Subscription）存储 ==========
    uint256 public nextTokenId = 1;
    mapping(uint256 => DataTypes.Subscription) public subscriptions;
    mapping(address => uint256[]) public userSubscriptions;

    // ========== 佣金（Commission）存储 ==========
    mapping(address => DataTypes.CommissionAccount) public commissionAccounts;
    uint256 public totalPendingCommissions;

    DataTypes.ReferralStats public referralStats;

    // ========== 基础配置 ==========
    DataTypes.BrandConfig public brandConfig;
    address public factory;
    bool public initialized;
}
