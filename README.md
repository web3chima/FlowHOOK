# FlowHook

A hybrid orderbook-AMM system built as a Uniswap V4 hook contract, implementing Kyle model mechanics with dynamic volatility adjustment based on open interest composition.

## Project Structure

```
.
├── src/
│   ├── DataStructures.sol      # Core data structures
│   ├── Constants.sol            # System constants
│   ├── Errors.sol               # Custom error definitions
│   ├── Events.sol               # Event definitions
│   └── interfaces/
│       └── IOrderbookHook.sol   # FlowHook interface definitions
├── test/
│   └── Setup.t.sol              # Base test setup
├── script/                      # Deployment scripts
├── lib/                         # Dependencies
│   ├── forge-std/               # Foundry standard library
│   ├── v4-core/                 # Uniswap V4 core
│   └── chainlink-brownie-contracts/  # Chainlink oracles
└── foundry.toml                 # Foundry configuration

```

## Dependencies

- **Uniswap V4 Core**: Hook integration and pool management
- **OpenZeppelin Contracts**: Access control and utilities (via v4-core)
- **Chainlink**: Price feed oracles
- **Forge-std**: Testing framework

## Key Features

- Traditional orderbook with price-time priority
- Kyle model price impact calculation
- Dynamic volatility based on open interest (OI)
- Concentrated liquidity AMM integration
- EIP-1153 transient storage for gas optimization
- Property-based testing framework

## OI-Volatility Relationship

- **Long OI**: Increases volatility (+3.569e-9 coefficient)
- **Short OI**: Decreases volatility (-1.678e-9 coefficient)

## Build & Test

```bash
# Build the project
forge build

# Run tests
forge test

# Run property-based tests
forge test --match-contract PropertyTest

# Run with verbosity
forge test -vvv
```

## Configuration

- **Solidity Version**: 0.8.24+
- **EVM Version**: Cancun (for EIP-1153 support)
- **Target Network**: Arc testnet (Prague EVM)
- **Fuzz Runs**: 256 (default), 1000 (PBT profile)

## Gas Targets

- Simple swaps: 150,000 gas
- Complex orderbook matches: 250,000 gas
- Contract size: < 24KB

## Development Status

This project is under active development for hackathon demonstration.
