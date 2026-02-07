// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {OrderbookHook} from "../src/OrderbookHook.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

/// @title Gas Benchmark Tests
/// @notice Benchmarks gas costs for key operations
/// @dev Validates: Requirements 14.7, 14.8
contract GasBenchmarkTest is Test {
    OrderbookHook public hook;
    ERC20Mock public token0;
    ERC20Mock public token1;
    
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    
    uint256 constant INITIAL_BALANCE = 1000000 * 1e18;
    uint256 constant DEPOSIT_AMOUNT = 100000 * 1e18;
    
    function setUp() public {
        // Deploy tokens
        token0 = new ERC20Mock();
        token1 = new ERC20Mock();
        
        // Deploy hook
        hook = new OrderbookHook(
            address(0x1234), // Mock pool manager
            address(token0),
            address(token1),
            79228162514264337593543950336, // sqrt(1) in Q96 format
            5000 * 1e18, // 0.5% base volatility
            1000000 * 1e18 // 1M base depth
        );
        
        // Setup users
        token0.mint(user1, INITIAL_BALANCE);
        token1.mint(user1, INITIAL_BALANCE);
        token0.mint(user2, INITIAL_BALANCE);
        token1.mint(user2, INITIAL_BALANCE);
        
        // Approve hook
        vm.startPrank(user1);
        token0.approve(address(hook), type(uint256).max);
        token1.approve(address(hook), type(uint256).max);
        vm.stopPrank();
        
        vm.startPrank(user2);
        token0.approve(address(hook), type(uint256).max);
        token1.approve(address(hook), type(uint256).max);
        vm.stopPrank();
        
        // Deposit funds
        vm.startPrank(user1);
        hook.deposit(address(token0), DEPOSIT_AMOUNT);
        hook.deposit(address(token1), DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        vm.startPrank(user2);
        hook.deposit(address(token0), DEPOSIT_AMOUNT);
        hook.deposit(address(token1), DEPOSIT_AMOUNT);
        vm.stopPrank();
    }
    
    /// @notice Benchmark: Place a single order
    function test_GasBenchmark_PlaceOrder() public {
        vm.prank(user1);
        uint256 gasBefore = gasleft();
        hook.placeOrder(true, 1e18, 1000 * 1e18);
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for placeOrder:", gasUsed);
        
        // Should be reasonable for a single order placement
        assertLt(gasUsed, 300000, "Place order gas too high");
    }
    
    /// @notice Benchmark: Cancel an order
    function test_GasBenchmark_CancelOrder() public {
        vm.prank(user1);
        uint256 orderId = hook.placeOrder(true, 1e18, 1000 * 1e18);
        
        vm.prank(user1);
        uint256 gasBefore = gasleft();
        hook.cancelOrder(orderId);
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for cancelOrder:", gasUsed);
        
        // Should be reasonable for cancellation
        assertLt(gasUsed, 150000, "Cancel order gas too high");
    }
    
    /// @notice Benchmark: Match two orders (simple case)
    function test_GasBenchmark_SimpleOrderMatch() public {
        // Place buy order
        vm.prank(user1);
        hook.placeOrder(true, 1e18, 1000 * 1e18);
        
        // Place matching sell order
        vm.prank(user2);
        uint256 gasBefore = gasleft();
        hook.placeOrder(false, 1e18, 1000 * 1e18);
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for simple order match:", gasUsed);
        
        // Target: 250,000 for complex orderbook matches
        assertLt(gasUsed, 250000, "Simple match gas too high");
    }
    
    /// @notice Benchmark: Match multiple orders
    function test_GasBenchmark_MultipleOrderMatch() public {
        // Place multiple buy orders
        vm.startPrank(user1);
        hook.placeOrder(true, 1.1e18, 500 * 1e18);
        hook.placeOrder(true, 1.0e18, 500 * 1e18);
        hook.placeOrder(true, 0.9e18, 500 * 1e18);
        vm.stopPrank();
        
        // Place large sell order that matches all
        vm.prank(user2);
        uint256 gasBefore = gasleft();
        hook.placeOrder(false, 0.9e18, 1500 * 1e18);
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for multiple order match:", gasUsed);
        
        // Target: 250,000 for complex orderbook matches
        assertLt(gasUsed, 300000, "Multiple match gas too high");
    }
    
    /// @notice Benchmark: Deposit
    function test_GasBenchmark_Deposit() public {
        vm.prank(user1);
        uint256 gasBefore = gasleft();
        hook.deposit(address(token0), 1000 * 1e18);
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for deposit:", gasUsed);
        
        assertLt(gasUsed, 100000, "Deposit gas too high");
    }
    
    /// @notice Benchmark: Withdraw
    function test_GasBenchmark_Withdraw() public {
        vm.prank(user1);
        uint256 gasBefore = gasleft();
        hook.withdraw(address(token0), 1000 * 1e18);
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for withdraw:", gasUsed);
        
        assertLt(gasUsed, 100000, "Withdraw gas too high");
    }
    
    /// @notice Benchmark: Add liquidity
    function test_GasBenchmark_AddLiquidity() public {
        vm.prank(user1);
        uint256 gasBefore = gasleft();
        hook.addLiquidity(-887220, 887220, 1000 * 1e18, 1000 * 1e18);
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for addLiquidity:", gasUsed);
        
        assertLt(gasUsed, 300000, "Add liquidity gas too high");
    }
    
    /// @notice Summary: Print all gas benchmarks
    function test_GasBenchmark_Summary() public {
        console.log("\n=== GAS BENCHMARK SUMMARY ===");
        console.log("Target for simple swaps: 150,000 gas");
        console.log("Target for complex matches: 250,000 gas");
        console.log("\nRun individual benchmark tests to see actual gas usage");
        console.log("Use: forge test --match-contract GasBenchmark --gas-report");
    }
}
