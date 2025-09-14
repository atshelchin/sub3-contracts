# Sub3 Contracts - 去中心化订阅管理平台

[English Version](README_EN.md)

一个基于以太坊的去中心化订阅管理系统，支持多层级订阅计划、推荐奖励机制和工厂模式部署。

## 📋 项目概述

Sub3 Contracts 是一个完整的区块链订阅服务解决方案，允许创作者和企业通过工厂合约部署自己的订阅服务，支持自定义品牌、定价策略和推荐系统。该系统特别适合需要订阅制收费的 DApp、内容创作者、SaaS 服务等场景。

### ✨ 核心特性

- **🏭 工厂模式部署**: 通过单一工厂合约部署多个独立的订阅项目
- **📊 四层订阅体系**: 支持 Starter、Standard、Pro、Max 四个订阅层级
- **⏱️ 灵活计费周期**: 支持日付、周付、月付、年付四种计费模式
- **💰 推荐奖励系统**: 推荐人获得 10% 佣金，被推荐人享受 10% 返现
- **🎨 品牌定制化**: 每个项目拥有独立的品牌标识（名称、符号、Logo、主题色）
- **⚡ Gas 优化**: 采用 Solady 库和克隆模式实现高效部署
- **📈 数据统计**: 全面的收入和用户数据追踪
- **🔒 安全机制**: 重入保护、访问控制、支付验证等多重安全措施
- **🌐 Web3 UI**: 提供完整的前端界面，支持 MetaMask 等钱包连接

## 系统架构

### 核心合约

#### Factory.sol (工厂合约)
负责部署新的订阅项目，采用克隆模式实现高效的 Gas 使用。

**主要功能:**
- `deployNewProject()`: 部署新的订阅项目，支持自定义品牌配置
- `setPlatformFeeBasisPoints()`: 设置平台费率（基点）
- `withdrawFees()`: 提取累积的平台费用
- `getProjectsPaginated()`: 分页查询已部署的项目
- `getRevenueStats()`: 获取平台收入统计数据

**收入来源:**
- 项目创建费: 0.01 ETH（默认）
- 平台抽成: 订阅收入的 5%（默认，最高30%）
- 直接存款: 支持接收 ETH 捐赠

#### Project.sol (项目合约)
管理单个订阅项目的订阅和奖励系统。

**订阅管理功能:**
- `subscribe()`: 首次订阅，支持推荐人机制
- `renew()`: 续订已过期的订阅
- `upgrade()`: 升级到更高层级（按比例计费）
- `downgrade()`: 降级到较低层级（仅在到期后）
- `extend()`: 延长当前订阅期限

**管理员功能:**
- `setPlanConfig()`: 更新层级定价和功能配置
- `updateBrandConfig()`: 修改品牌设置（名称和符号除外）
- `withdraw()`: 提取合约余额（不含待领取奖励）
- `emergencyPause()`: 紧急暂停功能

**推荐奖励系统:**
- 推荐人获得订阅费用的 10% 佣金
- 被推荐用户获得 10% 即时返现
- 7 天冷却期限制奖励领取频率
- 推荐人必须拥有活跃订阅才有效

#### ProjectReaderImpl.sol (读取器实现)
提供高效的数据查询功能，共享给所有项目使用。

**查询功能:**
- 获取用户订阅状态和历史
- 批量查询订阅者信息
- 获取推荐关系和奖励数据
- 统计数据汇总

### 辅助合约

#### DataTypes.sol (数据类型库)
定义系统中使用的所有数据结构:
- `BrandConfig`: 项目品牌配置信息
- `SubscriptionPlan`: 层级配置和定价
- `UserSubscription`: 用户订阅详情
- `ReferralAccount`: 推荐追踪和奖励
- `OperationRecord`: 操作历史记录

#### ProjectStorage.sol (存储布局)
项目合约的存储结构，继承自 Ownable。

### 接口定义

- **IFactory.sol**: 工厂合约接口
- **IProject.sol**: 项目合约完整接口
- **IProjectRead.sol**: 只读查询接口
- **IProjectWrite.sol**: 状态修改接口

## 💎 订阅层级

系统支持四个订阅层级，每个层级都可以配置不同的价格和功能：

### Starter 层级（入门版）
- **日付**: 项目方自定义
- **周付**: 项目方自定义
- **月付**: 项目方自定义
- **年付**: 项目方自定义（通常有折扣）
- **功能**: 基础功能集

### Standard 层级（标准版）
- **日付**: 项目方自定义
- **周付**: 项目方自定义
- **月付**: 项目方自定义
- **年付**: 项目方自定义（通常有折扣）
- **功能**: 标准功能集

### Pro 层级（专业版）
- **日付**: 项目方自定义
- **周付**: 项目方自定义
- **月付**: 0.01 ETH（示例价格）
- **年付**: 0.1 ETH（约 17% 折扣）
- **功能**: 高级功能集

### Max 层级（旗舰版）
- **日付**: 项目方自定义
- **周付**: 项目方自定义
- **月付**: 0.03 ETH（示例价格）
- **年付**: 0.3 ETH（约 17% 折扣）
- **功能**: 全部功能解锁

## 🎁 推荐奖励机制

推荐系统通过双向激励促进用户增长：

### 推荐人收益
- **佣金比例**: 获得被推荐人订阅费用的 10%
- **资格要求**: 必须拥有活跃的订阅
- **奖励累积**: 奖励自动累积到待领取余额
- **领取限制**: 每 7 天可领取一次累积奖励
- **追踪统计**: 记录推荐人数和总收益

### 被推荐人优惠
- **即时返现**: 订阅时立即获得 10% 返现
- **自动发放**: 返现直接发送到用户钱包
- **无需等待**: 不需要等待或手动领取
- **叠加优惠**: 可与其他优惠活动叠加

### 验证规则
- ✅ 推荐人必须有活跃订阅
- ❌ 不允许自我推荐
- ⚠️ 无效推荐人会被忽略（不会导致交易失败）
- 📊 所有推荐关系链上可查

## 💸 收入流向

订阅付款的资金分配流程：

```
订阅付款 (100%)
├── 平台费用 (5%) → 工厂合约
├── 推荐人奖励 (10%) → 推荐人待领取余额
├── 用户返现 (10%) → 订阅者（即时到账）
└── 净收入 (75%) → 项目合约
```

### 资金流转说明

1. **用户支付**: 用户支付全额订阅费用
2. **平台抽成**: 5% 自动转入工厂合约作为平台费
3. **推荐奖励**: 如有推荐人，10% 记入推荐人账户
4. **用户返现**: 如使用推荐码，10% 立即返还给用户
5. **项目收入**: 剩余资金归项目方所有

## 📊 数据统计

系统提供全面的数据追踪和统计功能：

### 工厂合约统计
- **创建费用总额**: 累计收取的项目创建费
- **平台费用总额**: 累计收取的平台抽成
- **直接存款总额**: 累计收到的直接转账
- **项目总数**: 已部署的项目数量
- **项目分布**: 各所有者的项目统计
- **收入趋势**: 时间维度的收入分析

### 项目合约统计
- **总收入**: 订阅付款总额
- **净收入**: 扣除费用和奖励后的收入
- **订阅者总数**: 历史订阅用户数
- **活跃订阅数**: 当前有效订阅数
- **推荐人数量**: 活跃推荐人统计
- **推荐奖励总额**: 已发放的推荐奖励
- **平台费用**: 已支付的平台费用
- **续订率**: 用户续订统计
- **升降级统计**: 订阅层级变化分析

## 🚀 快速开始

### 环境要求

- Node.js 16+
- [Foundry](https://getfoundry.sh/) 开发框架
- Solidity 0.8.13+
- MetaMask 或其他 Web3 钱包

### 安装部署

```bash
# 克隆仓库
git clone <repository-url>
cd sub3-contracts

# 安装依赖
forge install

# 编译合约
forge build

# 运行测试
forge test

# 本地部署
forge script script/Factory.s.sol --rpc-url localhost

# 主网部署
forge script script/Factory.s.sol --rpc-url mainnet --broadcast --verify
```

### 前端界面

项目包含完整的 Web3 前端界面（subscription-ui.html）：

```bash
# 直接打开 HTML 文件
open subscription-ui.html

# 或使用本地服务器
python -m http.server 8000
# 访问 http://localhost:8000/subscription-ui.html
```

### 测试覆盖

```bash
# 运行全部测试
forge test

# 详细输出
forge test -vvv

# 运行特定测试
forge test --match-contract ProjectTest

# 检查覆盖率
forge coverage

# Gas 报告
forge test --gas-report
```

## 🔐 安全性

### 安全措施

- **重入保护**: 所有支付函数使用 Solady 的 ReentrancyGuard
- **访问控制**: 管理员功能的严格权限控制
- **支付验证**: 严格的支付金额验证机制
- **溢出保护**: 全程使用安全的数学运算
- **推荐验证**: 全面的推荐人资格检查
- **时间锁**: 关键操作的时间锁保护
- **紧急暂停**: 支持紧急情况下的合约暂停

### Gas 优化

- **克隆模式**: 使用代理克隆最小化部署成本
- **Solady 库**: 采用优化的标准库实现
- **存储打包**: 高效的存储布局设计
- **批量操作**: 支持大数据集的分页查询
- **缓存机制**: 减少重复的存储读取
- **事件优化**: 精简的事件日志设计

### 审计状态

⚠️ **重要提示**: 该代码尚未经过专业审计，使用需自行承担风险。

建议在主网部署前：
1. 进行完整的安全审计
2. 实施多签钱包管理
3. 设置合理的限额和时间锁
4. 准备紧急响应预案

## 🌐 前端功能

### 用户界面

subscription-ui.html 提供完整的 DApp 界面：

- **钱包连接**: 支持 MetaMask、WalletConnect 等
- **网络切换**: 支持多链部署（Ethereum、BSC、Polygon 等）
- **项目部署**: 可视化的项目创建向导
- **订阅管理**: 订阅、续订、升级、降级操作
- **推荐系统**: 生成和使用推荐链接
- **数据看板**: 实时的收入和用户统计
- **多语言支持**: 中英文界面切换

### 管理功能

- **价格配置**: 动态调整各层级价格
- **品牌设置**: 更新项目品牌信息
- **收入提取**: 一键提取合约余额
- **数据导出**: 导出订阅者和交易数据

## 📝 使用示例

### 部署新项目

```javascript
// 连接钱包
await ethereum.request({ method: 'eth_requestAccounts' });

// 配置品牌信息
const brandConfig = {
    name: "My Subscription Service",
    symbol: "MSS",
    description: "Premium subscription service",
    logoUri: "https://example.com/logo.png",
    websiteUrl: "https://example.com",
    primaryColor: "#6366f1",
    maxTier: 3,
    enabledPeriods: [true, true, true, true],
    tierNames: ["Starter", "Standard", "Pro", "Max"]
};

// 设置价格矩阵（4x4）
const prices = [
    ["1000000000000000", "6000000000000000", "25000000000000000", "250000000000000000"], // Starter
    ["2000000000000000", "12000000000000000", "50000000000000000", "500000000000000000"], // Standard
    ["3000000000000000", "18000000000000000", "75000000000000000", "750000000000000000"], // Pro
    ["5000000000000000", "30000000000000000", "100000000000000000", "1000000000000000000"] // Max
];

// 部署项目
const tx = await factory.deployNewProject(
    brandConfig,
    ownerAddress,
    prices,
    { value: ethers.utils.parseEther("0.01") }
);
```

## 🤝 贡献指南

欢迎贡献代码！请遵循以下步骤：

1. Fork 本仓库
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

### 开发规范

- 遵循 Solidity 风格指南
- 所有新功能必须包含测试
- 保持代码覆盖率在 90% 以上
- 使用有意义的提交信息

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

## 📞 联系方式

- **问题反馈**: [GitHub Issues](https://github.com/your-repo/issues)
- **技术讨论**: [Discord](https://discord.gg/your-server)
- **官方网站**: [https://sub3.io](https://sub3.io)
- **邮箱**: support@sub3.io

## 🙏 致谢

- [Solady](https://github.com/Vectorized/solady) - 优化的 Solidity 库
- [Foundry](https://getfoundry.sh/) - 智能合约开发框架
- [OpenZeppelin](https://openzeppelin.com/) - 安全标准参考

## 📖 合约接口签名参考

### Factory 合约签名

#### 函数签名 (Functions)
```solidity
// 查询函数
projectImplementation()                    → 0x020e9a93
projectCreationFee()                        → 0x6bad6541
platformFeeBasisPoints()                    → 0xc58bfb66
projects(uint256)                           → 0x107046bd
calculatePlatformFee(uint256)               → 0x0cbab4f7
getTotalProjects()                          → 0x812739a2
getOwnerProjectCount(address)               → 0x7db2d9c7
isProjectNameTaken(string,string)           → 0xca017aef
getRevenueStats()                           → 0xac18992c
getProjectsPaginated(uint256,uint256)       → 0x33ee0568
getOwnerProjectsPaginated(address,uint256,uint256) → 0x4bc6d082

// 管理函数
setProjectCreationFee(uint256)              → 0x0db25b77
setProjectImplementation(address)           → 0x1f9e55b7
setPlatformFeeBasisPoints(uint256)          → 0xc247e686
deployNewProject(BrandConfig,address,uint256[4][4]) → 0x92c121a6
withdrawFees(address)                       → 0x164e68de
```

#### 错误签名 (Errors)
```solidity
InvalidFee(uint256,uint256)                 → 0xf05eb608
InvalidInput(string)                        → 0xd647364f
ZeroAddress()                               → 0xd92e233d
InvalidBasisPoints(uint256)                 → 0x197f1962
TransferFailed()                            → 0x90b8ec18
ProjectAlreadyExists(address)               → 0xe0a460cd
```

#### 事件签名 (Events)
```solidity
ProjectDeployed(address,address,string,string,uint256)
    → 0x82d2bdec36cf20e995d0ce1e3ce8a38bc182f92659dab188941a2eb513dbd9c5

CreationFeeUpdated(uint256,uint256)
    → 0x5de302eeb1c80d4fb0c0953b692353f09ddf431411b8eb2034d5e85769561912

PlatformFeeUpdated(uint256,uint256)
    → 0xd347e206f25a89b917fc9482f1a2d294d749baa4dc9bde7fb495ee11fe491643

ImplementationUpdated(address,address)
    → 0xaa3f731066a578e5f39b4215468d826cdd15373cbc0dfc9cb9bdc649718ef7da
```

### Project 合约签名

#### 函数签名 (Functions)
```solidity
// 初始化
initialize(BrandConfig,address,address,uint256[4][4]) → 0xc6135515

// 管理函数
setPlanConfig(uint8,uint256[4],string[])    → 0x2796a530
updateBrandConfig(BrandConfig)              → 0x962b6c96
withdraw(address)                           → 0x51cff8d9

// 订阅函数
subscribe(uint8,uint8,address)              → 0xe5392bf9
renew(uint8,uint8)                          → 0x94d74f45
upgrade(uint8,uint8)                        → 0x631864dd
downgrade(uint8,uint8)                      → 0x549d4ae4

// 推荐函数
claimReferralRewards()                      → 0x05eaab4b

// 查询函数
getBrandConfig()                            → 0xfdb78243
getEnabledPeriods()                         → 0x1ca2f88a
getTierNames()                              → 0x5ebdc22e
getPlan(uint8)                              → 0xa12b2121
getAllPlans()                               → 0x98de396a
getUserSubscription(address)                → 0xebbeec08
hasActiveSubscription(address)              → 0xbebe4a57
getReferralAccount(address)                 → 0x3171b76f
getReferralStats()                          → 0xbb4356a7
getUserTotalRewards(address)                → 0x666c4b5c
getProjectStats()                           → 0x2d6c1661
getWithdrawableBalance()                    → 0xbe788e70
getSubscribersPaginated(uint256,uint256)    → 0x414a1100
getReferralsPaginated(address,uint256,uint256) → 0x6b5adf3b
getOperationHistoryPaginated(uint256,uint256) → 0xa2aaed26
getUserOperationHistoryPaginated(address,uint256,uint256) → 0x7ee73053
```

#### 错误签名 (Errors)
```solidity
ProjectAlreadyInitialized()                 → 0x9398a190
NotInitialized()                            → 0x87138d5c
InvalidTier()                               → 0xe1423617
InvalidPeriod()                             → 0x17479ac8
InvalidPrice()                              → 0x00bfc921
InsufficientPayment()                       → 0xcd1c8867
ExcessPayment()                             → 0xc57d98bb
NoActiveSubscription()                      → 0x5eb24725
SubscriptionStillActive()                   → 0xe72f2f75
AlreadySubscribed()                         → 0x5fd8a132
CannotDowngradeToSameTier()                 → 0x144da5b6
CannotUpgradeToSameTier()                   → 0x384e4a22
InsufficientBalance()                       → 0xf4d678b8
TransferFailed()                            → 0x90b8ec18
ZeroAddress()                               → 0xd92e233d
ZeroAmount()                                → 0x1f2a2005
NoRewardsToClaim()                          → 0x73380d99
ClaimCooldownNotMet()                       → 0x7c170123
```

#### 事件签名 (Events)
```solidity
PlanConfigUpdated(uint8,uint256[4],string,string[])
    → 0xe60a3d5cf86d70b167bf9dabe0c57cc7588ce5bb77f1ad3ccccc2842ee1b8236

Subscribed(address,uint8,uint8,uint256,uint256)
    → 0xfcf95381264fce3d0acbb5d4a40f00c77c48d9cf3e842ad7fe58ef9f7f28278a

Renewed(address,uint8,uint8,uint256,uint256)
    → 0xeb3c6be4dd634a39db190ec19cf2b6c9713dc5d6b495a2e6d2306b7b93bda681

Upgraded(address,uint8,uint8,uint256,uint256)
    → 0x878f9a9d812d80cfb8bfdf46f3b54022bf1352a580946ad4dddc2053a7f6d597

Downgraded(address,uint8,uint8,uint8,uint256,uint256)
    → 0x67a8bb85cc575ca4a91129fa6a1b3a52fc9676be1bb2a0c790fa461e9704fec2

Withdrawn(address,uint256)
    → 0x7084f5476618d8e60b11ef0d7d3f06914655adb8793e28ff7f018d4c76d505d5

BrandConfigUpdated(string,string)
    → 0xe8d968cda3dc6327b5b331bdf9cf3e2e6de836f13f62c41983927d9737bcf689

ReferralRewardAccrued(address,address,uint256,uint256)
    → 0x927edc6a2ba12aea3853fd74ed72954a32b4a8d009004decf87af75d3ce20051

ReferralRewardsClaimed(address,uint256)
    → 0x98741ecf35c5d20a8ed68dbd8540500684864a6c98c2a41a5844d0b3a2357d43
```

### 枚举值映射

```solidity
// SubscriptionTier (uint8)
STARTER  = 0
STANDARD = 1
PRO      = 2
MAX      = 3

// SubscriptionPeriod (uint8)
DAILY    = 0
WEEKLY   = 1
MONTHLY  = 2
YEARLY   = 3

// OperationType (uint8)
SUBSCRIBE = 0
UPGRADE   = 1
DOWNGRADE = 2
RENEW     = 3
```

### 使用示例

#### Web3.js 调用示例
```javascript
// 获取用户订阅信息
const signature = '0xebbeec08'; // getUserSubscription(address)
const data = web3.eth.abi.encodeFunctionCall({
    name: 'getUserSubscription',
    type: 'function',
    inputs: [{type: 'address', name: 'user'}]
}, [userAddress]);

// 订阅服务
const subscribeSignature = '0xe5392bf9'; // subscribe(uint8,uint8,address)
const subscribeData = web3.eth.abi.encodeFunctionCall({
    name: 'subscribe',
    type: 'function',
    inputs: [
        {type: 'uint8', name: 'tier'},
        {type: 'uint8', name: 'period'},
        {type: 'address', name: 'referrer'}
    ]
}, [2, 2, referrerAddress]); // Pro tier, Monthly period
```

#### Ethers.js 错误处理示例
```javascript
try {
    await contract.subscribe(tier, period, referrer, {value: price});
} catch (error) {
    if (error.data?.startsWith('0xc57d98bb')) {
        console.error('支付金额过多 (ExcessPayment)');
    } else if (error.data?.startsWith('0xcd1c8867')) {
        console.error('支付金额不足 (InsufficientPayment)');
    } else if (error.data?.startsWith('0x5fd8a132')) {
        console.error('已经订阅 (AlreadySubscribed)');
    }
}
```

---

**免责声明**: 本项目仅供学习和研究使用，请勿在未经审计的情况下部署到主网。使用本代码产生的任何损失，开发者不承担责任。