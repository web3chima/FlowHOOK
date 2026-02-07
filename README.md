# FlowHook

A custom curve, independent market pricing mechanics system built as a Uniswap V4 hook contract, implementing Kyle model with dynamic volatility indicator based on open interest composition.

## 🎯 Enhanced Features (Latest Deployment)

- **Kyle Model Integration**: λ-based price impact calculation with cumulative order flow tracking
- **Dynamic Volatility**: OI-based volatility adjustments (+3.569e-9 long / -1.678e-9 short)
- **EIP-1153 TSTORE/TLOAD**: Transient storage for zero-cost mid-swap computations
- **Component Indicator**: ARIMA decomposition for expected/unexpected trading activity

## 📍 Deployed Contracts (Sepolia Testnet)

| Contract | Address |
|----------|---------|
| **FlowHookRouter** | [`0x316b52b9A364645b267c4a8eC69C871D917Ee2DD`](https://sepolia.etherscan.io/address/0x316b52b9A364645b267c4a8eC69C871D917Ee2DD) |
| **VAMMEngine** | [`0x6e5Dd3469def787961f7DBf865c99eEffE264A3c`](https://sepolia.etherscan.io/address/0x6e5Dd3469def787961f7DBf865c99eEffE264A3c) |
| **FeeEngine** | [`0xa5FeD68B6CF5818d14B2b1D245C49c04c856eeAf`](https://sepolia.etherscan.io/address/0xa5FeD68B6CF5818d14B2b1D245C49c04c856eeAf) |
| **OrderbookEngine** | [`0x3cCf24C3bF3F8B2908659C297068d298702E748A`](https://sepolia.etherscan.io/address/0x3cCf24C3bF3F8B2908659C297068d298702E748A) |
| **OracleEngine** | [`0x8Cd04F7C865dD940b906EdD9543e8E94BF42388f`](https://sepolia.etherscan.io/address/0x8Cd04F7C865dD940b906EdD9543e8E94BF42388f) |

**Deployment Date**: 2026-02-07 | **Network**: Sepolia (chainId: 11155111) | **EVM**: Cancun

## 📁 Project Structure

```
.
├── src/                         # Solidity contracts
│   ├── modules/                 # Modular architecture (deployed)
│   │   ├── FlowHookRouter.sol   # Main Uniswap V4 hook router
│   │   ├── VAMMEngine.sol       # Enhanced VAMM + Kyle model + TSTORE
│   │   ├── FeeEngine.sol        # Dynamic fee calculations
│   │   ├── OrderbookEngine.sol  # Limit order book
│   │   ├── OracleEngine.sol     # Price oracle integration
│   │   └── Interfaces.sol       # Contract interfaces
│   │
│   ├── libraries/               # Math libraries
│   │   ├── CurveMath.sol        # P = K × Q^(-2) curve math
│   │   ├── KyleMath.sol         # Kyle model calculations
│   │   ├── VolatilityMath.sol   # OI-volatility coefficients
│   │   ├── OrderbookMath.sol    # Orderbook operations
│   │   └── StorageOptimization.sol
│   │
│   ├── KyleModel.sol            # Kyle price impact (abstract)
│   ├── VolatilityCalculator.sol # OI-based volatility (abstract)
│   ├── ComponentIndicator.sol   # ARIMA activity decomposition
│   ├── CustomCurveEngine.sol    # Alternative curve engine
│   ├── DynamicFeeCalculator.sol # Fee calculation logic
│   ├── OracleManager.sol        # Chainlink integration
│   ├── OrderbookHook.sol        # Full monolithic hook (reference)
│   ├── DataStructures.sol       # Core data structures
│   ├── Constants.sol            # System constants
│   ├── Errors.sol               # Custom errors
│   └── Events.sol               # Event definitions
│
├── frontend/                    # React frontend
│   ├── src/
│   │   ├── abi/
│   │   │   └── contracts.ts     # ABIs + deployed addresses
│   │   ├── components/          # React components
│   │   │   ├── admin/           # Admin dashboard
│   │   │   ├── orderbook/       # Orderbook views
│   │   │   ├── trading/         # Trading interface
│   │   │   └── vamm/            # VAMM visualizations
│   │   ├── hooks/               # Custom React hooks
│   │   │   ├── useVAMM.ts       # VAMM state hook
│   │   │   ├── useOrderbook.ts  # Orderbook hook
│   │   │   └── useFees.ts       # Fee calculation hook
│   │   └── lib/contracts/       # Contract utilities
│   └── .env                     # Environment config
│
├── script/                      # Deployment scripts
│   ├── DeployModular.s.sol      # Modular deployment
│   └── Deploy.s.sol             # Original deployment
│
├── test/                        # Foundry tests
│   ├── CustomCurveEngine.t.sol  # Curve tests
│   ├── KyleModel.t.sol          # Kyle model tests
│   ├── VolatilityCalculator.t.sol
│   └── OrderbookHookIntegration.t.sol
│
└── broadcast/                   # Deployment logs
```

## 🏗 System Architecture 

```
┌─────────────────────────────────────────────────────────────────────┐
│                        UNISWAP V4 POOL MANAGER                     │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                    FlowHookRouter.sol                         │  │
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
│  │  │  - Reentrancy lock (zero-cost guard)                   │   │  │
│  │  │  - Fee calculation intermediaries                       │   │  │
│  │  │  - Component decomposition working data                │   │  │
│  │  │                                                        │   │  │
│  │  │  Cleared after each transaction (zero permanent cost)  │   │  │
│  │  └────────────────────────────────────────────────────────┘   │  │
│  │                          │                                    │  │
│  │         ┌────────────────┼────────────────┐                   │  │
│  │         ▼                ▼                ▼                   │  │
│  │  ┌────────────┐  ┌────────────┐  ┌──────────────┐            │  │
│  │  │  VAMM      │  │  FEE       │  │  ORDERBOOK   │            │  │
│  │  │  ENGINE    │  │  ENGINE    │  │  ENGINE      │            │  │
│  │  │            │  │            │  │              │            │  │
│  │  │ Kyle Model │  │ Dynamic    │  │ Limit Order  │            │  │
│  │  │ Volatility │  │ Fees       │  │ Matching     │            │  │
│  │  └─────┬──────┘  └─────┬──────┘  └──────┬───────┘            │  │
│  │        │               │                │                    │  │
│  └────────┼───────────────┼────────────────┼────────────────────┘  │
│           │               │                │                       │
└───────────┼───────────────┼────────────────┼───────────────────────┘
```

## 🔬 VAMMEngine Enhanced Features

### Kyle Model Integration
```solidity
// Price impact: λ × orderFlow
function getKyleModelState() external view returns (
    uint256 lambda,      // Price impact coefficient
    int256 flow,         // Cumulative order flow
    uint256 depth        // Effective market depth
);
```

### Volatility Calculator
```solidity
// OI-based volatility adjustment
function getVolatilityInfo() external view returns (
    uint256 baseVol,      // Base volatility (2%)
    uint256 effectiveVol, // Adjusted volatility
    uint256 longOI,       // Long open interest
    uint256 shortOI       // Short open interest
);
```

### TSTORE/TLOAD Events
```solidity
event CurveTradeExecuted(
    bool isLong, 
    uint256 size, 
    uint256 executionPrice, 
    uint256 priceImpact,
    uint256 kyleLambda,           // NEW: Kyle lambda
    uint256 effectiveVolatility   // NEW: Current volatility
);

event VolatilityUpdated(uint256 newVolatility, uint256 longOI, uint256 shortOI);
event KyleParametersUpdated(uint256 lambda, uint256 depth);
event TransientStateStored(bytes32 slot, uint256 value);
```

## 🛠 Build & Deploy

```bash
# Build
forge build

# Test
forge test

# Deploy to Sepolia
forge script script/DeployModular.s.sol:DeployModularScript \
  --rpc-url https://ethereum-sepolia-rpc.publicnode.com \
  --broadcast --verify -vvv
```

## ⚙️ Frontend Configuration

The frontend automatically uses the deployed addresses from `frontend/src/abi/contracts.ts`:

```typescript
export const CONTRACT_ADDRESSES = {
    FLOW_HOOK_ROUTER: "0x437fc35a835B6F92D8D108b1d50c5600C3a99bC9",
    VAMM_ENGINE: "0xAAAb75ddf3ac0C96c4fD3bE51e4F60dbAdcAdF12",
    FEE_ENGINE: "0x8331238ED47802b1C33051c834c76D4bB71d09c9",
    ORDERBOOK_ENGINE: "0x4885159349554bDFD8AaC481e86eea9331620280",
    ORACLE_ENGINE: "0x3359eA439F0fdb1542bCC99fc1B7F1fd9cf5348C",
    // ...
};
```

## 📊 Implementation Status

### Smart Contracts ✅

| Component | Status | Description |
|-----------|--------|-------------|
| `FlowHookRouter.sol` | ✅ Deployed | Main Uniswap V4 hook router |
| `VAMMEngine.sol` | ✅ Enhanced | Kyle model + TSTORE + volatility |
| `FeeEngine.sol` | ✅ Deployed | Dynamic fee calculations |
| `OrderbookEngine.sol` | ✅ Deployed | Limit order matching |
| `OracleEngine.sol` | ✅ Deployed | Price oracle |
| `KyleModel.sol` | ✅ Complete | λ price impact |
| `VolatilityCalculator.sol` | ✅ Complete | OI-based σ |
| `ComponentIndicator.sol` | ✅ Complete | ARIMA decomposition |

### Frontend ✅

| Component | Status | Description |
|-----------|--------|-------------|
| `contracts.ts` | ✅ Updated | ABIs + addresses |
| `VAMMDashboard.tsx` | ✅ Complete | Curve visualization |
| `AdminDashboard.tsx` | ✅ Complete | Parameter controls |
| `OrderbookView.tsx` | ✅ Complete | LOB/HYBRID display |

## 🔒 Security Considerations

⚠️ **Before Mainnet Deployment:**

1. Complete security audit
2. Formal verification of curve math
3. Test on testnet with real usage patterns
4. Review admin key management
5. Set up monitoring and alerting
