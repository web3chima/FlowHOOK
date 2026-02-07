// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {OrderbookHook} from "../src/OrderbookHook.sol";
import {CurveMode} from "../src/DataStructures.sol";

/// @title Deployment Script
/// @notice Script for deploying the Orderbook Hook to Arc testnet or mainnet
contract DeployScript is Script {
    // Deployment configuration
    struct DeployConfig {
        address poolManager;      // Uniswap V4 PoolManager
        address token0;           // Base token (e.g., WETH)
        address token1;           // Quote token (e.g., USDC)
        uint160 initialSqrtPriceX96; // Initial AMM price
        uint256 baseVolatility;   // Initial volatility (scaled 1e18)
        uint256 baseDepth;        // Initial orderbook depth
        CurveMode initialMode;    // Starting curve mode
        uint256 vammInitialPrice; // For VAMM: Initial price (e.g., 50000e18 for $50k)
        uint256 vammInitialQty;   // For VAMM: Initial vBTC quantity (e.g., 100e18)
    }

    function setUp() public {}

    function run() public virtual {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("========================================");
        console.log("FlowHook Orderbook Deployment Script");
        console.log("========================================");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        
        // Load configuration from environment
        DeployConfig memory config = loadConfig();
        
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy OrderbookHook
        console.log("");
        console.log("Step 1: Deploying OrderbookHook...");
        OrderbookHook hook = new OrderbookHook(
            config.poolManager,
            config.token0,
            config.token1,
            config.initialSqrtPriceX96,
            config.baseVolatility,
            config.baseDepth
        );
        console.log("OrderbookHook deployed at:", address(hook));

        // 2. Configure initial curve mode
        console.log("");
        console.log("Step 2: Configuring curve mode...");
        hook.setCurveMode(config.initialMode, address(0));
        console.log("Curve mode set to:", uint256(config.initialMode));

        // 3. If VAMM mode, initialize the custom curve
        if (config.initialMode == CurveMode.VAMM) {
            console.log("");
            console.log("Step 3: Initializing VAMM curve (P = K * Q^-2)...");
            hook.initializeVAMMCurve(config.vammInitialPrice, config.vammInitialQty);
            console.log("Initial price:", config.vammInitialPrice / 1e18, "USD");
            console.log("Initial quantity:", config.vammInitialQty / 1e18, "vBTC");
            
            // Calculate and log K
            uint256 k = (config.vammInitialPrice * config.vammInitialQty * config.vammInitialQty) / 1e18;
            console.log("Pool constant K:", k);
        }

        vm.stopBroadcast();

        // Log deployment summary
        logDeploymentSummary(address(hook), config);
    }

    function loadConfig() internal view returns (DeployConfig memory config) {
        // Load from environment variables with defaults
        config.poolManager = vm.envOr("POOL_MANAGER", address(0));
        config.token0 = vm.envOr("TOKEN0", address(0));
        config.token1 = vm.envOr("TOKEN1", address(0));
        
        // Default sqrtPriceX96 for ~$50,000 ETH/USDC price
        // sqrt(50000) * 2^96 ≈ 17.7e39
        config.initialSqrtPriceX96 = uint160(vm.envOr("INITIAL_SQRT_PRICE_X96", uint256(17715924907508430000000000000000000000000)));
        
        config.baseVolatility = vm.envOr("BASE_VOLATILITY", uint256(5000 * 1e18));
        config.baseDepth = vm.envOr("BASE_DEPTH", uint256(1000000 * 1e18));
        
        // Curve mode: 0=LOB, 1=HYBRID, 2=VAMM, 3=ORACLE
        uint256 modeInt = vm.envOr("CURVE_MODE", uint256(1)); // Default to HYBRID
        config.initialMode = CurveMode(modeInt);
        
        // VAMM configuration
        config.vammInitialPrice = vm.envOr("VAMM_INITIAL_PRICE", uint256(69420 * 1e18)); // $69,420 default (Realistic)
        config.vammInitialQty = vm.envOr("VAMM_INITIAL_QTY", uint256(5000 * 1e18)); // 5000 vBTC default (Low Sensitivity)
    }

    function logDeploymentSummary(address hookAddress, DeployConfig memory config) internal pure {
        console.log("");
        console.log("========================================");
        console.log("Deployment Summary");
        console.log("========================================");
        console.log("OrderbookHook:", hookAddress);
        console.log("PoolManager:", config.poolManager);
        console.log("Token0:", config.token0);
        console.log("Token1:", config.token1);
        console.log("Base Depth:", config.baseDepth / 1e18);
        console.log("Base Volatility:", config.baseVolatility / 1e18);
        console.log("Curve Mode:", uint256(config.initialMode));
        
        if (config.initialMode == CurveMode.VAMM) {
            console.log("VAMM Initial Price:", config.vammInitialPrice / 1e18);
            console.log("VAMM Initial Qty:", config.vammInitialQty / 1e18);
        }
        
        console.log("");
        console.log("Next steps:");
        console.log("1. Update frontend .env with contract address");
        console.log("2. Configure Chainlink price feeds if using ORACLE mode");
        console.log("3. Verify contract on block explorer");
    }
}

/// @title Testnet Deployment Script
/// @notice Pre-configured for Arc testnet deployment
contract DeployTestnetScript is DeployScript {
    function run() public override {
        // Override with testnet-specific config
        console.log("Deploying to Arc Testnet...");
        super.run();
    }
}

/// @title Mainnet Deployment Script  
/// @notice Pre-configured for production deployment
contract DeployMainnetScript is DeployScript {
    function run() public override {
        // Override with mainnet-specific config
        console.log("WARNING: Deploying to MAINNET!");
        console.log("Ensure all security checks have been completed.");
        super.run();
    }
}
