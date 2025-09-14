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

## 📖 Contract Interface Signatures Reference

### Factory Contract Signatures

#### Function Signatures
```solidity
// View Functions
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

// Admin Functions
setProjectCreationFee(uint256)              → 0x0db25b77
setProjectImplementation(address)           → 0x1f9e55b7
setPlatformFeeBasisPoints(uint256)          → 0xc247e686
deployNewProject(BrandConfig,address,uint256[4][4]) → 0x92c121a6
withdrawFees(address)                       → 0x164e68de
```

#### Error Signatures
```solidity
InvalidFee(uint256,uint256)                 → 0xf05eb608
InvalidInput(string)                        → 0xd647364f
ZeroAddress()                               → 0xd92e233d
InvalidBasisPoints(uint256)                 → 0x197f1962
TransferFailed()                            → 0x90b8ec18
ProjectAlreadyExists(address)               → 0xe0a460cd
```

#### Event Signatures
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

### Project Contract Signatures

#### Function Signatures
```solidity
// Initialization
initialize(BrandConfig,address,address,uint256[4][4]) → 0xc6135515

// Admin Functions
setPlanConfig(uint8,uint256[4],string[])    → 0x2796a530
updateBrandConfig(BrandConfig)              → 0x962b6c96
withdraw(address)                           → 0x51cff8d9

// Subscription Functions
subscribe(uint8,uint8,address)              → 0xe5392bf9
renew(uint8,uint8)                          → 0x94d74f45
upgrade(uint8,uint8)                        → 0x631864dd
downgrade(uint8,uint8)                      → 0x549d4ae4

// Referral Functions
claimReferralRewards()                      → 0x05eaab4b

// View Functions
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

#### Error Signatures
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

#### Event Signatures
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

### Enum Value Mappings

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

### Usage Examples

#### Web3.js Call Example
```javascript
// Get user subscription info
const signature = '0xebbeec08'; // getUserSubscription(address)
const data = web3.eth.abi.encodeFunctionCall({
    name: 'getUserSubscription',
    type: 'function',
    inputs: [{type: 'address', name: 'user'}]
}, [userAddress]);

// Subscribe to service
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

#### Ethers.js Error Handling Example
```javascript
try {
    await contract.subscribe(tier, period, referrer, {value: price});
} catch (error) {
    if (error.data?.startsWith('0xc57d98bb')) {
        console.error('Excess payment sent (ExcessPayment)');
    } else if (error.data?.startsWith('0xcd1c8867')) {
        console.error('Insufficient payment (InsufficientPayment)');
    } else if (error.data?.startsWith('0x5fd8a132')) {
        console.error('Already subscribed (AlreadySubscribed)');
    }
}
```

---

**Disclaimer**: This project is for learning and research purposes only. Do not deploy to mainnet without professional audit. The developers are not responsible for any losses resulting from the use of this code.