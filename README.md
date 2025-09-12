# Subscription Contracts

A decentralized subscription management system built with Solidity, featuring tiered plans, referral rewards, and factory pattern deployment.

## Overview

This project implements a comprehensive subscription platform on Ethereum, allowing creators to deploy their own subscription services with customizable pricing tiers, referral systems, and brand configurations.

### Key Features

- **Factory Pattern Deployment**: Deploy multiple independent subscription projects from a single factory
- **Tiered Subscriptions**: Support for PRO and MAX tiers with monthly/yearly billing periods
- **Referral System**: 10% rewards for referrers and 10% cashback for referred subscribers
- **Platform Fees**: Configurable platform fee collection (default 5%)
- **Brand Customization**: Each project has its own branding (name, symbol, logo, colors)
- **Gas Optimized**: Uses Solady library and clone pattern for efficient deployments

## Architecture

### Core Contracts

#### Factory.sol
The factory contract deploys new subscription projects using the clone pattern for gas efficiency.

**Key Functions:**
- `deployNewProject()`: Deploy a new subscription project with custom branding
- `setPlatformFeeBasisPoints()`: Configure platform fee percentage
- `withdrawFees()`: Withdraw accumulated platform fees
- `getProjectsPaginated()`: Query deployed projects with pagination

**Revenue Streams:**
- Project creation fees (0.01 ETH default)
- Platform fees from subscriptions (5% default)
- Direct ETH deposits

#### Project.sol
Individual subscription project contract managing subscriptions and rewards.

**Subscription Management:**
- `subscribe()`: First-time subscription with optional referrer
- `renew()`: Renew expired subscription
- `upgrade()`: Upgrade to higher tier (pro-rated)
- `downgrade()`: Downgrade to lower tier (only after expiry)

**Admin Functions:**
- `setPlanConfig()`: Update tier pricing and features
- `updateBrandConfig()`: Modify brand settings (except name/symbol)
- `withdraw()`: Withdraw contract balance

**Referral System:**
- Referrers earn 10% commission on referred subscriptions
- Subscribers get 10% cashback when using valid referrer
- 7-day cooldown between reward claims
- Referrer must have active subscription to be valid

### Supporting Contracts

#### DataTypes.sol
Defines all data structures used across the system:
- `BrandConfig`: Project branding information
- `SubscriptionPlan`: Tier configuration with pricing
- `UserSubscription`: Individual subscription details
- `ReferralAccount`: Referral tracking and rewards

#### ProjectStorage.sol
Storage layout for Project contracts, inheriting from Ownable.

### Interfaces

#### IFactory.sol
Interface for Factory contract with all public/external functions.

#### IProject.sol
Interface for Project contract with all public/external functions.

## Subscription Tiers

### PRO Tier
- Monthly: 0.01 ETH
- Yearly: 0.1 ETH (~17% discount)
- Basic features set

### MAX Tier
- Monthly: 0.03 ETH  
- Yearly: 0.3 ETH (~17% discount)
- Premium features set

## Referral Mechanism

The referral system incentivizes growth through mutual benefits:

1. **Referrer Benefits**: 
   - Earns 10% of referred subscription payments
   - Must have active subscription to qualify
   - Rewards accumulate and can be claimed every 7 days

2. **Subscriber Benefits**:
   - Receives 10% instant cashback when using valid referrer
   - Cashback sent directly during subscription

3. **Validation**:
   - Referrer must have active subscription
   - Self-referral is not allowed
   - Invalid referrers are silently ignored (no revert)

## Revenue Flow

```
Subscription Payment (100%)
├── Platform Fee (5%) → Factory Contract
├── Referrer Reward (10%) → Referrer's Pending Balance
├── Subscriber Cashback (10%) → Subscriber (instant)
└── Net Revenue (75%) → Project Contract
```

## Statistics Tracking

Both Factory and Project contracts track comprehensive statistics:

**Factory Stats:**
- Total creation fees collected
- Total platform fees received
- Total direct deposits
- Number of deployed projects

**Project Stats:**
- Gross revenue (total payments)
- Net revenue (after fees/rewards)
- Total subscribers
- Active referrers count
- Referral revenue and rewards
- Platform fees paid

## Development

### Prerequisites
- [Foundry](https://getfoundry.sh/) development framework
- Solidity 0.8.13+

### Installation

```bash
# Clone repository
git clone <repository-url>
cd sub3-contracts

# Install dependencies
forge install

# Run tests
forge test

# Deploy locally
forge script script/Factory.s.sol --rpc-url localhost
```

### Testing

The project includes comprehensive test coverage:

```bash
# Run all tests
forge test

# Run with verbosity
forge test -vv

# Run specific test contract
forge test --match-contract ProjectTest

# Check coverage
forge coverage
```

## Security Considerations

- **Reentrancy Protection**: All payment functions use Solady's ReentrancyGuard
- **Access Control**: Owner-only functions for administrative operations
- **Payment Validation**: Strict validation of payment amounts
- **Overflow Protection**: Safe math operations throughout
- **Referral Validation**: Comprehensive checks for referrer eligibility

## Gas Optimization

- **Clone Pattern**: Minimal deployment costs using proxy clones
- **Solady Library**: Optimized implementations of common patterns
- **Storage Packing**: Efficient storage layout design
- **Batch Operations**: Pagination support for large datasets

## License

MIT License - see LICENSE file for details

## Audit Status

⚠️ **This code has not been audited. Use at your own risk.**

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## Contact

For questions or support, please open an issue on GitHub.