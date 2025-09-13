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

---

**免责声明**: 本项目仅供学习和研究使用，请勿在未经审计的情况下部署到主网。使用本代码产生的任何损失，开发者不承担责任。