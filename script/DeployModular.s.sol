// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {FlowHookRouter} from "../src/modules/FlowHookRouter.sol";
import {VAMMEngine} from "../src/modules/VAMMEngine.sol";
import {FeeEngine} from "../src/modules/FeeEngine.sol";
import {OrderbookEngine} from "../src/modules/OrderbookEngine.sol";
import {OracleEngine} from "../src/modules/OracleEngine.sol";

interface AggregatorV3Interface {
  function latestRoundData() external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
  function decimals() external view returns (uint8);
}

/// @title Deploy Modular FlowHook
/// @notice Deploys all FlowHook modules separately for production
contract DeployModularScript is Script {
    
    struct DeploymentConfig {
        address poolManager;
        address token0;
        address token1;
        uint256 vammInitialPrice;
        uint256 vammInitialQty;
        uint24 baseFee;
        // Kyle model and volatility parameters
        uint256 baseDepth;
        uint256 baseVolatility;
        uint256 maxVolatility;
    }
    
    struct DeployedContracts {
        address router;
        address vammEngine;
        address feeEngine;
        address orderbookEngine;
        address oracleEngine;
    }
    
    function run() public returns (DeployedContracts memory deployed) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("========================================");
        console.log("FlowHook Modular Deployment");
        console.log("========================================");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("");
        
        // Load configuration
        DeploymentConfig memory config = _loadConfig();
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Step 1: Deploy VAMMEngine (with Kyle model and volatility params)
        console.log("Step 1: Deploying VAMMEngine...");
        console.log("  Base Depth:", config.baseDepth);
        console.log("  Base Volatility:", config.baseVolatility);
        console.log("  Max Volatility:", config.maxVolatility);
        VAMMEngine vammEngine = new VAMMEngine(
            config.baseDepth,
            config.baseVolatility,
            config.maxVolatility
        );
        console.log("  VAMMEngine deployed at:", address(vammEngine));
        
        // Step 2: Deploy FeeEngine
        console.log("Step 2: Deploying FeeEngine...");
        FeeEngine feeEngine = new FeeEngine(config.baseFee);
        console.log("  FeeEngine deployed at:", address(feeEngine));

        // Step 2.5: Deploy OrderbookEngine
        console.log("Step 2.5: Deploying OrderbookEngine...");
        OrderbookEngine orderbookEngine = new OrderbookEngine();
        console.log("  OrderbookEngine deployed at:", address(orderbookEngine));

        // Step 2.6: Deploy OracleEngine
        console.log("Step 2.6: Deploying OracleEngine...");
        OracleEngine oracleEngine = new OracleEngine();
        console.log("  OracleEngine deployed at:", address(oracleEngine));
        
        // Step 3: Deploy FlowHookRouter
        console.log("Step 3: Deploying FlowHookRouter...");
        FlowHookRouter router = new FlowHookRouter(
            config.poolManager,
            config.token0,
            config.token1
        );
        console.log("  FlowHookRouter deployed at:", address(router));
        
        // Step 4: Configure router with engine addresses
        console.log("Step 4: Connecting engines to router...");
        router.setVAMMEngine(address(vammEngine));
        router.setFeeEngine(address(feeEngine));
        router.setOrderbookEngine(address(orderbookEngine));
        router.setOracleEngine(address(oracleEngine));
        console.log("  Engines connected!");
        
        // Step 5: Initialize VAMM curve
        console.log("Step 5: Initializing VAMM curve...");
        vammEngine.initialize(config.vammInitialPrice, config.vammInitialQty);
        console.log("  Initial price:", config.vammInitialPrice / 1e18, "USD");
        console.log("  Initial quantity:", config.vammInitialQty / 1e18, "vBTC");

        // Step 6: Seed Orderbook (LOB Mode Demo)
        console.log("Step 6: Seeding Orderbook...");
        // Sell Orders (Ask)
        orderbookEngine.placeOrder(69500e18, 10e18, false); // Sell 10 @ $69,500
        orderbookEngine.placeOrder(69600e18, 5e18, false);  // Sell 5 @ $69,600
        // Buy Orders (Bid)
        orderbookEngine.placeOrder(69300e18, 10e18, true);  // Buy 10 @ $69,300
        orderbookEngine.placeOrder(69200e18, 5e18, true);   // Buy 5 @ $69,200
        console.log("  Seeded LOB with orders around $69,420");

        // Step 7: Configure Oracle (Live Mode)
        // Sepolia BTC/USD Feed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43
        address oracleFeed = vm.envOr("ORACLE_FEED", address(0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43));
        console.log("Step 7: Setting Chainlink Feed:", oracleFeed);
        oracleEngine.setPriceFeed(oracleFeed);
        
        vm.stopBroadcast();
        
        // Print summary
        console.log("");
        console.log("========================================");
        console.log("DEPLOYMENT SUCCESSFUL!");
        console.log("========================================");
        console.log("");
        console.log("Deployed Contracts:");
        console.log("  FlowHookRouter:", address(router));
        console.log("  VAMMEngine:    ", address(vammEngine));
        console.log("  FeeEngine:     ", address(feeEngine));
        console.log("  OrderbookEngine:", address(orderbookEngine));
        console.log("  OracleEngine:   ", address(oracleEngine));
        console.log("");
        console.log("Configuration:");
        console.log("  PoolManager:", config.poolManager);
        console.log("  Token0 (WETH):", config.token0);
        console.log("  Token1 (USDC):", config.token1);
        console.log("  Base Fee:", config.baseFee, "bps");
        console.log("");
        console.log("========================================");
        console.log("NEXT STEPS:");
        console.log("========================================");
        console.log("1. Update frontend .env with:");
        console.log("   VITE_HOOK_ADDRESS=", address(router));
        console.log("");
        console.log("2. Verify contracts on Etherscan:");
        console.log("   forge verify-contract", address(router), "src/modules/FlowHookRouter.sol:FlowHookRouter");
        console.log("");
        
        deployed = DeployedContracts({
            router: address(router),
            vammEngine: address(vammEngine),
            feeEngine: address(feeEngine),
            orderbookEngine: address(orderbookEngine),
            oracleEngine: address(oracleEngine)
        });
    }
    
    function _loadConfig() internal view returns (DeploymentConfig memory config) {
        // Try to load from env, with defaults
        config.poolManager = vm.envOr("POOL_MANAGER", address(0xE03A1074c86CFeDd5C142C4F04F1a1536e203543));
        config.token0 = vm.envOr("TOKEN0", address(0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9));
        config.token1 = vm.envOr("TOKEN1", address(0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8));
        
        // Initialize with LIVE Chainlink Price (No more hardcoded 69420)
        address btcFeed = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43;
        try AggregatorV3Interface(btcFeed).latestRoundData() returns (uint80, int256 answer, uint256, uint256, uint80) {
            // Chainlink is 8 decimals, VAMM needs 18 decimals
            config.vammInitialPrice = uint256(answer) * 1e10; 
            console.log("Fetched Live BTC Price:", config.vammInitialPrice / 1e18);
        } catch {
            console.log("Failed to fetch live price, using fallback");
            config.vammInitialPrice = 69420e18; // Fallback if oracle fails (e.g. offline)
        }
        
        config.vammInitialQty = 5000e18;    // vm.envOr("VAMM_INITIAL_QTY", uint256(5000e18));
        
        // Fee config - 0.3% base fee
        config.baseFee = uint24(vm.envOr("BASE_FEE", uint256(3000)));
        
        // Kyle model parameters - depth reflects market liquidity
        config.baseDepth = vm.envOr("BASE_DEPTH", uint256(1000e18)); // 1000 units base depth
        
        // Volatility parameters - scaled by 1e18
        config.baseVolatility = vm.envOr("BASE_VOLATILITY", uint256(2e16)); // 2% base volatility
        config.maxVolatility = vm.envOr("MAX_VOLATILITY", uint256(2e17));   // 20% max volatility
    }
}
