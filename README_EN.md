# Sub3 Contracts - Decentralized Subscription Management Platform

[中文版](README.md)

A decentralized subscription management system built on Ethereum, featuring multi-tier subscription plans, referral rewards mechanism, and factory pattern deployment.

## 📋 Overview

Sub3 Contracts is a comprehensive blockchain subscription service solution that allows creators and businesses to deploy their own subscription services through factory contracts, supporting custom branding, pricing strategies, and referral systems. The system is particularly suitable for DApps, content creators, and SaaS services that require subscription-based monetization.

### ✨ Key Features

- **🏭 Factory Pattern Deployment**: Deploy multiple independent subscription projects through a single factory contract
- **📊 Four-Tier Subscription System**: Support for Starter, Standard, Pro, and Max subscription tiers
- **⏱️ Flexible Billing Periods**: Support for daily, weekly, monthly, and yearly billing modes
- **💰 Referral Reward System**: Referrers earn 10% commission, referred users get 10% cashback
- **🎨 Brand Customization**: Each project has independent brand identity (name, symbol, logo, theme color)
- **⚡ Gas Optimization**: Efficient deployment using Solady library and clone pattern
- **📈 Data Analytics**: Comprehensive revenue and user data tracking
- **🔒 Security Mechanisms**: Multiple security measures including reentrancy protection, access control, and payment validation
- **🌐 Web3 UI**: Complete frontend interface with MetaMask and other wallet support

## 🏗️ System Architecture

### Core Contracts

#### Factory.sol
Responsible for deploying new subscription projects using clone pattern for efficient gas usage.

**Main Functions:**
- `deployNewProject()`: Deploy new subscription project with custom brand configuration
- `setPlatformFeeBasisPoints()`: Set platform fee rate (in basis points)
- `withdrawFees()`: Withdraw accumulated platform fees
- `getProjectsPaginated()`: Query deployed projects with pagination
- `getRevenueStats()`: Get platform revenue statistics

**Revenue Sources:**
- Project creation fee: 0.01 ETH (default)
- Platform commission: 5% of subscription revenue (default, max 30%)
- Direct deposits: Support for ETH donations

#### Project.sol
Manages subscriptions and reward system for individual subscription projects.

**Subscription Management:**
- `subscribe()`: First-time subscription with optional referrer
- `renew()`: Renew expired subscription
- `upgrade()`: Upgrade to higher tier (pro-rated)
- `downgrade()`: Downgrade to lower tier (only after expiry)
- `extend()`: Extend current subscription period

**Admin Functions:**
- `setPlanConfig()`: Update tier pricing and feature configuration
- `updateBrandConfig()`: Modify brand settings (except name and symbol)
- `withdraw()`: Withdraw contract balance (excluding pending rewards)
- `emergencyPause()`: Emergency pause functionality

**Referral System:**
- Referrers earn 10% commission on subscription fees
- Referred users get 10% instant cashback
- 7-day cooldown period for reward claims
- Referrer must have active subscription to be valid

#### ProjectReaderImpl.sol
Provides efficient data query functionality shared across all projects.

**Query Functions:**
- Get user subscription status and history
- Batch query subscriber information
- Get referral relationships and reward data
- Statistical data aggregation

### Supporting Contracts

#### DataTypes.sol
Defines all data structures used in the system:
- `BrandConfig`: Project brand configuration
- `SubscriptionPlan`: Tier configuration and pricing
- `UserSubscription`: User subscription details
- `ReferralAccount`: Referral tracking and rewards
- `OperationRecord`: Operation history records

#### ProjectStorage.sol
Storage layout for Project contracts, inheriting from Ownable.

### Interface Definitions

- **IFactory.sol**: Factory contract interface
- **IProject.sol**: Complete project contract interface
- **IProjectRead.sol**: Read-only query interface
- **IProjectWrite.sol**: State modification interface

## 💎 Subscription Tiers

The system supports four subscription tiers, each configurable with different prices and features:

### Starter Tier
- **Daily**: Project-defined pricing
- **Weekly**: Project-defined pricing
- **Monthly**: Project-defined pricing
- **Yearly**: Project-defined pricing (usually discounted)
- **Features**: Basic feature set

### Standard Tier
- **Daily**: Project-defined pricing
- **Weekly**: Project-defined pricing
- **Monthly**: Project-defined pricing
- **Yearly**: Project-defined pricing (usually discounted)
- **Features**: Standard feature set

### Pro Tier
- **Daily**: Project-defined pricing
- **Weekly**: Project-defined pricing
- **Monthly**: 0.01 ETH (example price)
- **Yearly**: 0.1 ETH (~17% discount)
- **Features**: Advanced feature set

### Max Tier
- **Daily**: Project-defined pricing
- **Weekly**: Project-defined pricing
- **Monthly**: 0.03 ETH (example price)
- **Yearly**: 0.3 ETH (~17% discount)
- **Features**: All features unlocked

## 🎁 Referral Rewards Mechanism

The referral system promotes user growth through mutual incentives:

### Referrer Benefits
- **Commission Rate**: 10% of referred subscription fees
- **Eligibility**: Must have active subscription
- **Reward Accumulation**: Rewards automatically accumulate to pending balance
- **Claim Restrictions**: Can claim accumulated rewards every 7 days
- **Tracking**: Records number of referrals and total earnings

### Referred User Benefits
- **Instant Cashback**: 10% cashback on subscription
- **Automatic Distribution**: Cashback sent directly to wallet
- **No Waiting**: No need to wait or manually claim
- **Stackable Benefits**: Can be combined with other promotions

### Validation Rules
- ✅ Referrer must have active subscription
- ❌ Self-referral not allowed
- ⚠️ Invalid referrers are silently ignored (no transaction failure)
- 📊 All referral relationships are on-chain verifiable

## 💸 Revenue Flow

Fund allocation flow for subscription payments:

```
Subscription Payment (100%)
├── Platform Fee (5%) → Factory Contract
├── Referrer Reward (10%) → Referrer's Pending Balance
├── Subscriber Cashback (10%) → Subscriber (instant)
└── Net Revenue (75%) → Project Contract
```

### Fund Flow Explanation

1. **User Payment**: User pays full subscription fee
2. **Platform Commission**: 5% automatically transferred to factory contract
3. **Referral Reward**: If referrer exists, 10% credited to referrer account
4. **User Cashback**: If referral code used, 10% immediately returned to user
5. **Project Revenue**: Remaining funds belong to project owner

## 📊 Data Statistics

The system provides comprehensive data tracking and analytics:

### Factory Contract Statistics
- **Total Creation Fees**: Cumulative project creation fees collected
- **Total Platform Fees**: Cumulative platform commissions collected
- **Total Direct Deposits**: Cumulative direct transfers received
- **Total Projects**: Number of deployed projects
- **Project Distribution**: Project statistics by owner
- **Revenue Trends**: Time-based revenue analysis

### Project Contract Statistics
- **Gross Revenue**: Total subscription payments
- **Net Revenue**: Revenue after fees and rewards
- **Total Subscribers**: Historical subscriber count
- **Active Subscriptions**: Current valid subscriptions
- **Referrer Count**: Active referrer statistics
- **Total Referral Rewards**: Distributed referral rewards
- **Platform Fees Paid**: Platform fees paid
- **Renewal Rate**: User renewal statistics
- **Tier Changes**: Subscription tier change analysis

## 🚀 Quick Start

### Prerequisites

- Node.js 16+
- [Foundry](https://getfoundry.sh/) development framework
- Solidity 0.8.13+
- MetaMask or other Web3 wallet

### Installation & Deployment

```bash
# Clone repository
git clone <repository-url>
cd sub3-contracts

# Install dependencies
forge install

# Compile contracts
forge build

# Run tests
forge test

# Local deployment
forge script script/Factory.s.sol --rpc-url localhost

# Mainnet deployment
forge script script/Factory.s.sol --rpc-url mainnet --broadcast --verify
```

### Frontend Interface

The project includes a complete Web3 frontend interface (subscription-ui.html):

```bash
# Open HTML file directly
open subscription-ui.html

# Or use local server
python -m http.server 8000
# Access http://localhost:8000/subscription-ui.html
```

### Test Coverage

```bash
# Run all tests
forge test

# Verbose output
forge test -vvv

# Run specific tests
forge test --match-contract ProjectTest

# Check coverage
forge coverage

# Gas report
forge test --gas-report
```

## 🔐 Security

### Security Measures

- **Reentrancy Protection**: All payment functions use Solady's ReentrancyGuard
- **Access Control**: Strict permission control for admin functions
- **Payment Validation**: Strict payment amount validation mechanism
- **Overflow Protection**: Safe math operations throughout
- **Referral Validation**: Comprehensive referrer eligibility checks
- **Time Locks**: Time lock protection for critical operations
- **Emergency Pause**: Contract pause support for emergencies

### Gas Optimization

- **Clone Pattern**: Minimize deployment costs using proxy clones
- **Solady Library**: Optimized standard library implementations
- **Storage Packing**: Efficient storage layout design
- **Batch Operations**: Pagination support for large datasets
- **Caching Mechanism**: Reduce redundant storage reads
- **Event Optimization**: Streamlined event logging design

### Audit Status

⚠️ **Important**: This code has not been professionally audited. Use at your own risk.

Recommendations before mainnet deployment:
1. Conduct comprehensive security audit
2. Implement multi-sig wallet management
3. Set reasonable limits and time locks
4. Prepare emergency response plan

## 🌐 Frontend Features

### User Interface

subscription-ui.html provides a complete DApp interface:

- **Wallet Connection**: Support for MetaMask, WalletConnect, etc.
- **Network Switching**: Multi-chain deployment support (Ethereum, BSC, Polygon, etc.)
- **Project Deployment**: Visual project creation wizard
- **Subscription Management**: Subscribe, renew, upgrade, downgrade operations
- **Referral System**: Generate and use referral links
- **Data Dashboard**: Real-time revenue and user statistics
- **Multi-language Support**: English/Chinese interface switching

### Admin Features

- **Price Configuration**: Dynamically adjust tier pricing
- **Brand Settings**: Update project brand information
- **Revenue Withdrawal**: One-click contract balance withdrawal
- **Data Export**: Export subscriber and transaction data

## 📝 Usage Examples

### Deploy New Project

```javascript
// Connect wallet
await ethereum.request({ method: 'eth_requestAccounts' });

// Configure brand information
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

// Set price matrix (4x4)
const prices = [
    ["1000000000000000", "6000000000000000", "25000000000000000", "250000000000000000"], // Starter
    ["2000000000000000", "12000000000000000", "50000000000000000", "500000000000000000"], // Standard
    ["3000000000000000", "18000000000000000", "75000000000000000", "750000000000000000"], // Pro
    ["5000000000000000", "30000000000000000", "100000000000000000", "1000000000000000000"] // Max
];

// Deploy project
const tx = await factory.deployNewProject(
    brandConfig,
    ownerAddress,
    prices,
    { value: ethers.utils.parseEther("0.01") }
);
```

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to branch (`git push origin feature/AmazingFeature`)
5. Open Pull Request

### Development Standards

- Follow Solidity style guide
- All new features must include tests
- Maintain code coverage above 90%
- Use meaningful commit messages

## 📄 License

MIT License - See [LICENSE](LICENSE) file for details

## 📞 Contact

- **Issue Tracking**: [GitHub Issues](https://github.com/your-repo/issues)
- **Technical Discussion**: [Discord](https://discord.gg/your-server)
- **Official Website**: [https://sub3.io](https://sub3.io)
- **Email**: support@sub3.io

## 🙏 Acknowledgments

- [Solady](https://github.com/Vectorized/solady) - Optimized Solidity library
- [Foundry](https://getfoundry.sh/) - Smart contract development framework
- [OpenZeppelin](https://openzeppelin.com/) - Security standard reference

---

**Disclaimer**: This project is for learning and research purposes only. Do not deploy to mainnet without professional audit. The developers are not responsible for any losses resulting from the use of this code.