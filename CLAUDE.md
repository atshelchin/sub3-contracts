# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Development Commands

### Building and Testing
- `forge build` - Compile all smart contracts
- `forge test` - Run all tests
- `forge test -vvv` - Run tests with verbose output (shows console logs and detailed traces)
- `forge test --match-test <testName>` - Run a specific test function
- `forge test --match-contract <ContractName>` - Run tests for a specific contract

### Code Quality
- `forge fmt` - Format Solidity code
- `forge fmt --check` - Check if code is properly formatted without making changes
- `forge snapshot` - Generate gas usage snapshots for tests

### Deployment and Scripts
- `forge script script/<ScriptName>.s.sol` - Run a deployment script locally
- `forge script script/<ScriptName>.s.sol --rpc-url <url> --broadcast` - Deploy to a network

### Local Development
- `anvil` - Start a local Ethereum node for testing

## Codebase Architecture

This is a Foundry-based smart contract project with the following structure:

### Core Contracts (`src/`)
Smart contracts are located in the `src/` directory. The main entry point is typically the primary contract file.

### Testing Framework (`test/`)
Tests follow Foundry conventions:
- Test contracts inherit from `forge-std/Test.sol`
- Test functions are prefixed with `test` for regular tests or `testFuzz` for fuzz tests
- The `setUp()` function runs before each test
- Tests use Foundry's assertion methods like `assertEq`, `assertTrue`, etc.

### Deployment Scripts (`script/`)
Deployment scripts inherit from `forge-std/Script.sol` and use:
- `vm.startBroadcast()` and `vm.stopBroadcast()` to mark transaction boundaries
- The `run()` function as the main entry point

### Dependencies
The project uses `forge-std` as a git submodule in `lib/` for testing utilities and standard libraries.

### CI/CD
GitHub Actions workflow runs on push and pull requests, executing:
1. Code formatting check (`forge fmt --check`)
2. Contract compilation with size output (`forge build --sizes`)
3. Test suite with verbose output (`forge test -vvv`)