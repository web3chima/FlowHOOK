# FlowHook

A custom curve, independent market pricing mechanics system built as a Uniswap V4 hook contract, implementing Kyle model with dynamic volatility indicator based on open interest composition.

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
## System Architecture 

FlowHook System Architecture
 High-Level Overview

FlowHook is a Uniswap V4 hook that combines a deleveraging indicator, custom curve,
independent market pricing mechanics, and dynamic fees in a single Solidity contract.


```

┌─────────────────────────────────────────────────────────────────────┐
│                        UNISWAP V4 POOL MANAGER                     │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                    FlowHook.sol (Single Contract)             │  │
│  │                                                               │  │
│  │  ┌─────────────┐  ┌──────────────┐  ┌─────────────────────┐  │  │
│  │  │  beforeSwap  │  │  afterSwap   │  │  beforeModify       │  │  │
│  │  │  Hook        │  │  Hook        │  │  Position Hook      │  │  │
│  │  └──────┬───────┘  └──────┬───────┘  └──────────┬──────────┘  │  │
│  │         │                 │                      │             │  │
│  │         ▼                 ▼                      ▼             │  │
│  │  ┌────────────────────────────────────────────────────────┐   │  │
│  │  │           EIP-1153 TRANSIENT STORAGE LAYER             │   │  │
│  │  │                                                        │   │  │
│  │  │  TSTORE/TLOAD: mid-transaction computation scratch     │   │  │
│  │  │  - Pool depth deltas (ΔQ_vBTC)                         │   │  │
│  │  │  - Intermediate volatility estimates                    │   │  │
│  │  │  - Fee calculation intermediaries                       │   │  │
│  │  │  - Component decomposition working data                │   │  │
│  │  │                                                        │   │  │
│  │  │  Cleared after each transaction (zero permanent cost)  │   │  │
│  │  └────────────────────────────────────────────────────────┘   │  │
│  │                          │                                    │  │
│  │         ┌────────────────┼────────────────┐                   │  │
│  │         ▼                ▼                ▼                   │  │
│  │  ┌────────────┐  ┌────────────┐  ┌──────────────┐            │  │
│  │  │  CUSTOM    │  │  DYNAMIC   │  │  COMPONENT   │            │  │
│  │  │  CURVE     │  │  FEE       │  │  INDICATOR   │            │  │
│  │  │  ENGINE    │  │  ENGINE    │  │  ENGINE      │            │  │
│  │  └─────┬──────┘  └─────┬──────┘  └──────┬───────┘            │  │
│  │        │               │                │                    │  │
│  └────────┼───────────────┼────────────────┼────────────────────┘  │
│           │               │                │                       │
└───────────┼───────────────┼────────────────┼───────────────────────┘
           │               │                │
           ▼               ▼                ▼
```

## Core Engines

Custom Curve Engine — Deleveraging & Independent Pricing


Implements the pricing formula derived from the critical asymmetry finding:


```
P_vBTC = k × Q_vBTC⁻²


Where:
 k       = pool constant
 Q_vBTC  = quantity of vBTC in pool
 P_vBTC  = derived price


Long opened  → Q_vBTC decreases → P sensitivity increases → volatility ↑
Short opened → Q_vBTC increases → P sensitivity decreases → volatility ↓
```


Supports 4 independent pricing mechanisms via a unified interface:


```
┌───────────────────────────────────────────────────────┐
│              CUSTOM CURVE ENGINE                      │
│                                                       │
│  ┌─────────────┐  ┌─────────────┐                    │
│  │ LOB Mode    │  │ Hybrid Mode │                    │
│  │ (Binance    │  │ (dYdX       │                    │
│  │  style)     │  │  style)     │                    │
│  │             │  │             │                    │
│  │ Traders:    │  │ Traders:    │                    │
│  │ Price MAKERS│  │ Price MAKERS│                    │
│  └─────────────┘  └─────────────┘                    │
│                                                       │
│  ┌─────────────┐  ┌──────────────────┐               │
│  │ VAMM Mode  │  │ Oracle Mode      │               │
│  │ (Perp       │  │ (GMX/GNS style)  │               │
│  │  style)     │  │                  │               │
│  │             │  │ Traders:         │               │
│  │ Traders:    │  │ Price TAKERS     │               │
│  │ Pool MOVERS │  │                  │               │
│  └──────┬──────┘  └────────┬─────────┘               │
│         │                  │                         │
│         │         ┌────────▼─────────┐               │
│         │         │ Chainlink Oracle │               │
│         │         │ Price Feed       │               │
│         │         └──────────────────┘               │
│         │                                            │
│         ▼                                            │
│  ┌──────────────────────────────────┐                │
│  │ Long/Short Asymmetry Handler    │                │
│  │                                  │                │
│  │ Long OI coef:  +3.569e-9  (↑σ)  │                │
│  │ Short OI coef: -1.678e-9  (↓σ)  │                │
│  │                                  │                │
│  │ Deleveraging trigger logic:      │                │
│  │ When σ_estimated > threshold →   │                │
│  │ adjust curve to reduce exposure  │                │
│  └──────────────────────────────────┘                │
└───────────────────────────────────────────────────────┘
```

## Dynamic Fee Engine — VAMM Hook Swap Fees


```
┌───────────────────────────────────────────────────┐
│              DYNAMIC FEE ENGINE                   │
│                                                   │
│  Inputs (from transient storage):                 │
│  ├── Current pool depth (Q_vBTC)                  │
│  ├── Open interest imbalance (long - short)       │
│  ├── Estimated volatility (σ_hat)                 │
│  └── Speculative component ratio                  │
│                                                   │
│              ┌──────────────┐                     │
│              │  Fee = f(σ,  │                     │
│              │    OI_imbal, │                     │
│              │    depth)    │                     │
│              └──────┬───────┘                     │
│                     │                             │
│                     ▼                             │
│  ┌──────────────────────────────────────┐         │
│  │ Higher volatility    → Higher fee    │         │
│  │ Deeper pool          → Lower fee     │         │
│  │ OI imbalance (longs) → Higher fee    │         │
│  │ Balanced OI          → Base fee      │         │
│  └──────────────────────────────────────┘         │
└───────────────────────────────────────────────────┘

```
## Component Indicator Engine — Decomposition

Splits trading activity into expected (hedger/informed) and unexpected (speculative):

```
┌───────────────────────────────────────────────────────┐
│           COMPONENT INDICATOR ENGINE                  │
│                                                       │
│  Raw Trading Activity                                 │
│  ┌──────────┬──────────┬──────────┬──────────┐        │
│  │ Volume   │ Open     │ Liquida- │ Leverage │        │
│  │          │ Interest │ tions    │          │        │
│  └────┬─────┴────┬─────┴────┬─────┴────┬─────┘        │
│       │          │          │          │              │
│       ▼          ▼          ▼          ▼              │
│  ┌──────────────────────────────────────────┐         │
│  │         ARIMA Decomposition              │         │
│  │         (on-chain approximation)         │         │
│  └─────────────┬────────────────────────────┘         │
│                │                                      │
│       ┌────────┴────────┐                             │
│       ▼                 ▼                             │
│  ┌──────────┐     ┌───────────┐                       │
│  │ EXPECTED │     │ UNEXPECTED│                       │
│  │ (Hedger/ │     │ (Specula- │                       │
│  │ Informed)│     │  tive)    │                       │
│  └──────────┘     └───────────┘                       │
│                                                       │
│  → Fed to Custom Curve + Dynamic Fee engines          │
│  → Exposed to Admin Dashboard                         │
└───────────────────────────────────────────────────────┘

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
