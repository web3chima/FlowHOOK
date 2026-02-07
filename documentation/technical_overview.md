# 🌊 FlowHook: The Future of Decentralized Perpetual Trading

---

## 📽️ Demo Video Script & Presentation

### Slide 1: Title
**FlowHook** — A Multi-Curve Perpetual Trading Protocol Built on Uniswap V4

---

## 🎯 The Problem We Solve

### Current DeFi Trading Limitations
| Problem | Impact |
|---------|--------|
| **Single AMM model** | One-size-fits-all doesn't work for all market conditions |
| **High slippage** | Large trades move prices unfavorably |
| **No real-time price feeds** | DEXs can lag behind global markets |
| **Lack of leverage** | Traders can't amplify positions |
| **Liquidity fragmentation** | Assets scattered across multiple protocols |

### FlowHook's Solution
✅ **4 interchangeable pricing curves** — switch on-the-fly
✅ **Virtual AMM** — guaranteed liquidity, no external LPs needed
✅ **Oracle integration** — real-world price accuracy
✅ **Perpetual contracts** — long/short positions with leverage

---

## 🧬 Technology Stack

### Smart Contracts
| Layer | Technology | Purpose |
|-------|------------|---------|
| **Base** | Ethereum (Sepolia Testnet) | L1 Security |
| **Protocol** | Uniswap V4 (Singleton) | Pool infrastructure |
| **Hook** | FlowHook Router | Custom pricing logic |
| **Engines** | Modular Solidity contracts | VAMM, LOB, Oracle, Fee |

### Frontend
| Technology | Purpose |
|------------|---------|
| **React 18** | UI framework |
| **Vite** | Build tool |
| **Wagmi + Viem** | Blockchain interactions |
| **TanStack Query** | Data fetching & caching |
| **Recharts** | Price charts |
| **Tailwind CSS** | Styling |

---

## 📈 The 4 Pricing Curves

### 1. VAMM (Virtual AMM)
```
P = K × Q⁻²  →  Price = Constant / Quantity²
```
**Benefits:**
- ✅ Always available liquidity
- ✅ No external LPs needed
- ✅ Predictable slippage
- ✅ Great for bootstrapping new markets

**How it works:**
- Creates a "virtual" pool of synthetic assets
- Price changes based on demand (buying increases price)
- Pool constant K ensures mathematical consistency

---

### 2. LOB (Limit Order Book)
```
Match buyers ←→ sellers at exact prices
```
**Benefits:**
- ✅ Zero slippage at your price
- ✅ Traditional trading experience
- ✅ Price discovery through real orders

**How it works:**
- Users place limit orders (buy at $X, sell at $Y)
- Orders stored on-chain in priority order
- Matching engine fills orders when prices cross

---

### 3. HYBRID
```
Try LOB first, fall back to VAMM
```
**Benefits:**
- ✅ Best of both worlds
- ✅ Human liquidity when available
- ✅ Guaranteed execution via VAMM

**How it works:**
- Check orderbook for matching orders
- If no match → execute against VAMM
- Weighted price from both sources

---

### 4. ORACLE
```
Price = Chainlink BTC/USD feed
```
**Benefits:**
- ✅ Real-world price accuracy
- ✅ No manipulation risk
- ✅ Institutional-grade data

**How it works:**
- Fetches live BTC price from Chainlink
- Trades execute at global market price
- Minimal slippage for small trades

---

## 🏗️ Architecture Deep Dive

### Modular "Hub & Spoke" Design

```
┌─────────────────────────────────────────────────────┐
│                   UNISWAP V4                         │
│                  PoolManager                         │
└───────────────────────┬─────────────────────────────┘
                        │ beforeSwap()
                        ▼
┌─────────────────────────────────────────────────────┐
│              FlowHookRouter (Hub)                    │
│  • Decides active curve mode                         │
│  • Routes trades to appropriate engine               │
│  • Emits SwapExecuted events                         │
└───────┬───────────┬───────────┬───────────┬─────────┘
        │           │           │           │
        ▼           ▼           ▼           ▼
┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐
│ VAMMEngine│ │OrderBook  │ │OracleEng. │ │ FeeEngine │
│           │ │ Engine    │ │           │ │           │
│ P = K/Q²  │ │ Bid/Ask   │ │ Chainlink │ │ Dynamic   │
│           │ │ Matching  │ │ Feed      │ │ Fees      │
└───────────┘ └───────────┘ └───────────┘ └───────────┘
```

### Why This Design?
1. **Separation of concerns** — Each engine does one thing well
2. **Easy upgrades** — Swap engines without redeploying everything
3. **Gas efficiency** — Only load code for active curve
4. **Security** — Isolated failure domains

---

## 💡 Key Features

### 1. Live Price Chart
- Real BTC/USD data from CoinGecko
- Your trades appear as markers
- Fullscreen mode for presentations

### 2. Multi-Curve Switching
- Change pricing model with one click
- Each mode optimized for different scenarios
- Admin dashboard for governance

### 3. Position Management
- Track long/short positions
- Real-time P&L calculation
- One-click close

### 4. Trade History
- All trades stored on-chain
- Fetched via event logs
- Transparent and verifiable

### 5. Transaction Receipts
- Confirmation for every trade
- Network details (Sepolia testnet)
- Shareable proof of execution

---

## 🔧 Smart Contract Files

| Contract | Purpose | Lines |
|----------|---------|-------|
| [FlowHookRouter.sol](file:///c:/Users/sonwa/Downloads/Tradfi/src/modules/FlowHookRouter.sol) | Main entry point, curve switching | ~400 |
| [VAMMEngine.sol](file:///c:/Users/sonwa/Downloads/Tradfi/src/modules/VAMMEngine.sol) | Virtual AMM math | ~300 |
| [OrderbookEngine.sol](file:///c:/Users/sonwa/Downloads/Tradfi/src/modules/OrderbookEngine.sol) | Limit order matching | ~200 |
| [OracleEngine.sol](file:///c:/Users/sonwa/Downloads/Tradfi/src/modules/OracleEngine.sol) | Chainlink integration | ~100 |
| [FeeEngine.sol](file:///c:/Users/sonwa/Downloads/Tradfi/src/modules/FeeEngine.sol) | Dynamic fee calculation | ~100 |

---

## 🎮 Demo Flow

### Step 1: Connect Wallet
- MetaMask on Sepolia testnet
- Get testnet ETH from faucet

### Step 2: View Live Chart
- Real BTC price data
- Fullscreen mode available

### Step 3: Switch Curve Mode
- VAMM → LOB → HYBRID → ORACLE
- Watch header price change

### Step 4: Execute Trade
- Enter size (e.g., 0.1 BTC)
- Click Buy/Sell
- Approve transaction

### Step 5: View Results
- Trade appears in History tab
- Position shows in Positions tab
- Trade marker on chart

---

## 📊 Use Cases

### For Traders
| Use Case | Best Curve |
|----------|------------|
| Small trades, low slippage | ORACLE |
| Large trades, guaranteed execution | VAMM |
| Exact price, willing to wait | LOB |
| Best price available now | HYBRID |

### For Market Makers
- Provide liquidity via LOB orders
- Earn spread on matched trades
- No impermanent loss (order-based)

### For Protocol Builders
- Fork and customize for any asset
- Plug in your own engine logic
- Modular, extensible architecture

---

## 🛡️ Security Considerations

| Aspect | Approach |
|--------|----------|
| **Access Control** | Admin-only curve switching |
| **Input Validation** | Size/price bounds checks |
| **Reentrancy** | Mutex locks on critical functions |
| **Oracle Manipulation** | Chainlink decentralized feeds |
| **Overflow/Underflow** | Solidity 0.8+ built-in checks |

---

## 🚀 Future Roadmap

### Phase 1: Mainnet Launch
- Deploy to Ethereum mainnet
- Integrate Chainlink production feeds
- Security audit

### Phase 2: Multi-Asset
- Add ETH, SOL, and stablecoin perps
- Cross-margin positions
- Portfolio management

### Phase 3: Advanced Features
- Funding rates
- Insurance fund
- Partial liquidations
- Governance token

---

## 📁 Project Structure

```
Tradfi/
├── src/                    # Smart contracts
│   ├── modules/            # Engine contracts
│   └── libraries/          # Shared math
├── frontend/               # React app
│   ├── src/
│   │   ├── components/     # UI components
│   │   ├── hooks/          # Blockchain hooks
│   │   ├── abi/            # Contract ABIs
│   │   └── lib/            # Utilities
│   └── public/             # Static assets
├── script/                 # Deployment scripts
├── test/                   # Contract tests
└── documentation/          # This file!
```

---

## 🎬 Demo Video Talking Points

### Opening (0:00 - 0:30)
> "Today I'm presenting FlowHook, a revolutionary perpetual trading protocol built on Uniswap V4 that allows traders to switch between four different pricing mechanisms on the fly."

### The Problem (0:30 - 1:00)
> "Traditional AMMs use a single pricing formula. But what if market conditions change? What if you need guaranteed execution? What if you want real-world prices?"

### The Solution (1:00 - 2:00)
> "FlowHook solves this with four interchangeable curves: VAMM for virtual liquidity, LOB for exact prices, HYBRID for the best of both, and ORACLE for real-world accuracy."

### Live Demo (2:00 - 4:00)
> "Let me show you the UI. Here's the live BTC chart... I'll switch to VAMM mode... execute a trade... and watch it appear on the chart."

### Architecture (4:00 - 5:00)
> "Under the hood, we use a modular hub-and-spoke design. The FlowHookRouter decides which engine handles your trade, making upgrades seamless."

### Closing (5:00 - 5:30)
> "FlowHook represents the next evolution in DeFi trading. Questions?"

---

## 📞 Contact & Links

- **GitHub**: [FlowHook Repository](https://github.com/your-repo)
- **Deployed Contracts**: Sepolia Testnet
- **Frontend**: http://localhost:5173 (dev)

---

*Built for Hackathon 2026* 🏆
