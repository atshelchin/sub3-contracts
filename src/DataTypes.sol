// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title DataTypes
 * @notice 数据结构定义
 * @dev Edition = 版本（如2024春季版），Plan = 计划（如基础计划、专业计划）
 */
library DataTypes {
    // ========== 版本（Edition）相关 ==========

    /**
     * @notice 版本信息
     * @dev 一个版本包含多个订阅计划
     */
    struct Edition {
        uint256 id; // 版本ID
        string name; // 版本名称，如"2024春季版"
        bool isActive; // 是否为当前活跃版本
        uint256 createdAt; // 创建时间
        PlanConfig[3] plans; // 三个计划配置（价格为0表示不可用）
        address svgRenderer; // SVG渲染器地址（每个版本可以有不同的视觉样式）
    }

    /**
     * @notice 计划配置
     * @dev 版本中的具体订阅计划
     */
    struct PlanConfig {
        string name; // 计划名称，如"专业计划"
        uint256 price; // 价格
        uint256 duration; // 时长（天），0表示永久
        string[] benefits; // 权益描述列表（用于展示）
    }



    // ========== 订阅（Subscription）相关 ==========

    /**
     * @notice 订阅信息
     * @dev 用户的订阅实例，以NFT形式存在
     */
    struct Subscription {
        uint256 editionId; // 所属版本ID
        uint8 planId; // 计划ID（0-2）
        address subscriber; // 订阅者
        address referrer; // 推荐人
        uint256 startTime; // 开始时间
        uint256 expiryTime; // 到期时间
        uint256 renewCount; // 续费次数
        uint256 totalPaid; // 累计支付
    }

    // ========== 佣金（Commission）相关 ==========

    /**
     * @notice 佣金账户
     * @dev 推荐人的佣金管理
     */
    struct CommissionAccount {
        uint256 pending; // 待领取佣金
        uint256 totalEarned; // 历史总收入
        uint256 lastClaimTime; // 上次领取时间
        uint256 referralCount; // 成功推荐次数
    }

    // ========== 统计（Stats）相关 ==========

    struct ReferralStats {
        uint256 referrerCount;
        uint256 referralCount;
        uint256 referralRevenue;
    }

    /**
     * @notice 计划统计
     */
    struct PlanStats {
        uint256 subscriberCount; // 订阅数量
        uint256 revenue; // 收入金额
    }

    /**
     * @notice 版本统计
     */
    struct EditionStats {
        uint256 totalSubscribers; // 总订阅数（历史累计）
        uint256 totalRevenue; // 总收入
        PlanStats[3] planStats; // 各计划的详细统计
    }

    struct BrandConfig {
        string name; // 名称
        string symbol; // 符号
        string description; // 描述
        string logoUri; // Logo
        string websiteUrl; // 官网
        string primaryColor; // 品牌色
    }
}
