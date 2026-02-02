// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {OrderbookHook} from "../src/OrderbookHook.sol";
import {KyleState, VolatilityState, PackedFeeState, ComponentIndicatorState} from "../src/DataStructures.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract OrderbookHookIntegrationTest is Test {
    OrderbookHook public hook;
    
    address public poolManager;
    address public token0;
    address public token1;
    address public user1;
    address public user2;
    
    uint160 public constant INITIAL_SQRT_PRICE = 79228162514264337593543950336; // sqrt(1) in Q64.96
    uint256 public constant INITIAL_VOLATILITY = 1e18; // 100% volatility
    uint256 public constant INITIAL_DEPTH = 1000000e18; // 1M depth
    uint256 public constant INITIAL_ORACLE_PRICE = 1e18; // 1:1 price
    
    function setUp() public {
        // Setup addresses
        poolManager = address(0x1);
        token0 = address(0x2);
        token1 = address(0x3);
        user1 = address(0x4);
        user2 = address(0x5);
        
        // Deploy the integrated hook (removed oracle price parameter)
        hook = new OrderbookHook(
            poolManager,
            token0,
            token1,
            INITIAL_SQRT_PRICE,
            INITIAL_VOLATILITY,
            INITIAL_DEPTH
        );
    }
    
    function test_DeploymentSuccess() public view {
        // Verify deployment
        assertEq(address(hook.poolManager()), poolManager);
        // Note: token0 and token1 are internal immutable variables, cannot be accessed directly
        // We can verify through other means like checking orderbook depth
        (uint256 buyDepth, uint256 sellDepth) = hook.getOrderbookDepth();
        assertEq(buyDepth, 0);
        assertEq(sellDepth, 0);
    }
    
    function test_SystemStateInitialization() public view {
        // Get system state
        (
            KyleState memory kyleState,
            VolatilityState memory volatilityState,
            PackedFeeState memory feeState,
            ComponentIndicatorState memory componentState
        ) = hook.getSystemState();
        
        // Verify Kyle state
        assertEq(kyleState.baseDepth, INITIAL_DEPTH);
        
        // Verify volatility state
        assertEq(volatilityState.baseVolatility, INITIAL_VOLATILITY);
        assertEq(volatilityState.longOI, 0);
        assertEq(volatilityState.shortOI, 0);
        
        // Verify fee state
        assertGt(feeState.baseFee, 0);
        assertGt(feeState.maxFee, feeState.baseFee);
    }
    
    function test_OrderbookDepthInitialization() public view {
        (uint256 buyDepth, uint256 sellDepth) = hook.getOrderbookDepth();
        assertEq(buyDepth, 0);
        assertEq(sellDepth, 0);
    }
    
    function test_ComponentsAreWired() public view {
        // Verify all components are accessible
        
        // Orderbook
        assertEq(hook.nextOrderId(), 1);
        
        // Liquidity Manager
        (
            uint256 reserve0,
            uint256 reserve1,
            uint160 sqrtPriceX96,
            int24 currentTick,
            uint128 totalLiquidity
        ) = hook.getPoolState();
        assertEq(sqrtPriceX96, INITIAL_SQRT_PRICE);
        assertEq(totalLiquidity, 0);
        
        // Kyle Model - use getKyleState()
        KyleState memory kyleState = hook.getKyleState();
        assertEq(kyleState.baseDepth, INITIAL_DEPTH);
        
        // Volatility Calculator - use getVolatilityState()
        VolatilityState memory volatilityState = hook.getVolatilityState();
        assertEq(volatilityState.baseVolatility, INITIAL_VOLATILITY);
        
        // Dynamic Fee Manager - feeState is public, access individual fields
        (uint24 currentFee, uint24 baseFee, uint24 maxFee, uint32 lastUpdateBlock, bool isPaused) = hook.feeState();
        assertGt(baseFee, 0);
        assertFalse(isPaused);
        
        // Component Indicator - use getState()
        ComponentIndicatorState memory componentState = hook.getState();
        assertEq(componentState.totalVolume, 0);
        
        // De-leveraging Curve - TWAP starts at 0 until prices are added
        assertEq(hook.getTWAP(), 0);
    }
}
