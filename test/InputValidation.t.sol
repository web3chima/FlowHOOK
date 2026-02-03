// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {OrderbookHook} from "../src/OrderbookHook.sol";
import {InputValidator} from "../src/InputValidator.sol";
import {InvalidInput, ZeroAmount} from "../src/Errors.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Input Validation Property Test
/// @notice Property-based tests for input validation across all user-facing functions
contract InputValidationTest is Test {
    OrderbookHook public hook;
    address public token0;
    address public token1;
    address public poolManager;
    address public admin;
    address public user1;
    
    // Mock ERC20 token for testing
    MockERC20 public mockToken0;
    MockERC20 public mockToken1;
    
    function setUp() public {
        admin = address(this);
        user1 = makeAddr("user1");
        
        // Deploy mock tokens
        mockToken0 = new MockERC20("Token0", "TK0");
        mockToken1 = new MockERC20("Token1", "TK1");
        
        token0 = address(mockToken0);
        token1 = address(mockToken1);
        
        // Deploy mock pool manager
        poolManager = address(new MockPoolManager());
        
        // Deploy OrderbookHook
        hook = new OrderbookHook(
            poolManager,
            token0,
            token1,
            79228162514264337593543950336, // Initial sqrt price (1:1)
            1e18, // Base volatility
            1000e18 // Base depth
        );
        
        // Mint tokens to user
        mockToken0.mint(user1, 1000000e18);
        mockToken1.mint(user1, 1000000e18);
        
        // Approve hook to spend tokens
        vm.prank(user1);
        mockToken0.approve(address(hook), type(uint256).max);
        vm.prank(user1);
        mockToken1.approve(address(hook), type(uint256).max);
    }
    
    // ============ Property 37: Input Validation ============
    
    /// @notice Property 37: Input Validation - Deposit with zero address
    /// @dev For any user input, the system SHALL validate it against expected ranges and formats, rejecting invalid inputs
    function testProperty_InputValidation_DepositZeroAddress() public {
        // Feature: uniswap-v4-orderbook-hook, Property 37: Input Validation
        
        vm.startPrank(user1);
        
        // Attempt to deposit with zero address should revert
        vm.expectRevert(abi.encodeWithSelector(InvalidInput.selector, "token"));
        hook.deposit(address(0), 100e18);
        
        vm.stopPrank();
    }
    
    /// @notice Property 37: Input Validation - Deposit with zero amount
    function testProperty_InputValidation_DepositZeroAmount() public {
        // Feature: uniswap-v4-orderbook-hook, Property 37: Input Validation
        
        vm.startPrank(user1);
        
        // Attempt to deposit zero amount should revert
        vm.expectRevert(ZeroAmount.selector);
        hook.deposit(token0, 0);
        
        vm.stopPrank();
    }
    
    /// @notice Property 37: Input Validation - Withdraw with zero address
    function testProperty_InputValidation_WithdrawZeroAddress() public {
        // Feature: uniswap-v4-orderbook-hook, Property 37: Input Validation
        
        vm.startPrank(user1);
        
        // First deposit some tokens
        hook.deposit(token0, 100e18);
        
        // Attempt to withdraw with zero address should revert
        vm.expectRevert(abi.encodeWithSelector(InvalidInput.selector, "token"));
        hook.withdraw(address(0), 50e18);
        
        vm.stopPrank();
    }
    
    /// @notice Property 37: Input Validation - Withdraw with zero amount
    function testProperty_InputValidation_WithdrawZeroAmount() public {
        // Feature: uniswap-v4-orderbook-hook, Property 37: Input Validation
        
        vm.startPrank(user1);
        
        // First deposit some tokens
        hook.deposit(token0, 100e18);
        
        // Attempt to withdraw zero amount should revert
        vm.expectRevert(ZeroAmount.selector);
        hook.withdraw(token0, 0);
        
        vm.stopPrank();
    }
    
    /// @notice Property 37: Input Validation - Place order with zero price
    function testProperty_InputValidation_PlaceOrderZeroPrice() public {
        // Feature: uniswap-v4-orderbook-hook, Property 37: Input Validation
        
        vm.startPrank(user1);
        
        // Deposit tokens first
        hook.deposit(token1, 1000e18);
        
        // Attempt to place order with zero price should revert
        vm.expectRevert(ZeroAmount.selector);
        hook.placeOrder(true, 0, 100e18);
        
        vm.stopPrank();
    }
    
    /// @notice Property 37: Input Validation - Place order with zero quantity
    function testProperty_InputValidation_PlaceOrderZeroQuantity() public {
        // Feature: uniswap-v4-orderbook-hook, Property 37: Input Validation
        
        vm.startPrank(user1);
        
        // Deposit tokens first
        hook.deposit(token1, 1000e18);
        
        // Attempt to place order with zero quantity should revert
        vm.expectRevert(ZeroAmount.selector);
        hook.placeOrder(true, 1e18, 0);
        
        vm.stopPrank();
    }
    
    /// @notice Property 37: Input Validation - Place order with price out of bounds (too high)
    function testProperty_InputValidation_PlaceOrderPriceTooHigh() public {
        // Feature: uniswap-v4-orderbook-hook, Property 37: Input Validation
        
        vm.startPrank(user1);
        
        // Deposit tokens first
        hook.deposit(token1, 1000e18);
        
        // Attempt to place order with price > 1e30 should revert
        vm.expectRevert(abi.encodeWithSelector(InvalidInput.selector, "price out of bounds"));
        hook.placeOrder(true, 1e30 + 1, 100e18);
        
        vm.stopPrank();
    }
    
    /// @notice Property 37: Input Validation - Place order with quantity out of bounds (too high)
    function testProperty_InputValidation_PlaceOrderQuantityTooHigh() public {
        // Feature: uniswap-v4-orderbook-hook, Property 37: Input Validation
        
        vm.startPrank(user1);
        
        // Deposit a large amount of tokens first
        mockToken1.mint(user1, 1e31);
        
        // Attempt to place order with quantity > 1e30 should revert
        vm.expectRevert(abi.encodeWithSelector(InvalidInput.selector, "quantity out of bounds"));
        hook.placeOrder(true, 1e18, 1e30 + 1);
        
        vm.stopPrank();
    }
    
    /// @notice Property 37: Input Validation - Add liquidity with invalid tick range (lower >= upper)
    function testProperty_InputValidation_AddLiquidityInvalidTickRange() public {
        // Feature: uniswap-v4-orderbook-hook, Property 37: Input Validation
        
        vm.startPrank(user1);
        
        // Deposit tokens first
        hook.deposit(token0, 1000e18);
        hook.deposit(token1, 1000e18);
        
        // Attempt to add liquidity with tickLower >= tickUpper should revert
        vm.expectRevert(abi.encodeWithSelector(InvalidInput.selector, "invalid tick range"));
        hook.addLiquidity(100, 100, 100e18, 100e18);
        
        vm.stopPrank();
    }
    
    /// @notice Property 37: Input Validation - Add liquidity with tick out of bounds (too low)
    function testProperty_InputValidation_AddLiquidityTickTooLow() public {
        // Feature: uniswap-v4-orderbook-hook, Property 37: Input Validation
        
        vm.startPrank(user1);
        
        // Deposit tokens first
        hook.deposit(token0, 1000e18);
        hook.deposit(token1, 1000e18);
        
        // Attempt to add liquidity with tickLower < -887272 should revert
        vm.expectRevert(abi.encodeWithSelector(InvalidInput.selector, "tick out of bounds"));
        hook.addLiquidity(-887273, 100, 100e18, 100e18);
        
        vm.stopPrank();
    }
    
    /// @notice Property 37: Input Validation - Add liquidity with tick out of bounds (too high)
    function testProperty_InputValidation_AddLiquidityTickTooHigh() public {
        // Feature: uniswap-v4-orderbook-hook, Property 37: Input Validation
        
        vm.startPrank(user1);
        
        // Deposit tokens first
        hook.deposit(token0, 1000e18);
        hook.deposit(token1, 1000e18);
        
        // Attempt to add liquidity with tickUpper > 887272 should revert
        vm.expectRevert(abi.encodeWithSelector(InvalidInput.selector, "tick out of bounds"));
        hook.addLiquidity(-100, 887273, 100e18, 100e18);
        
        vm.stopPrank();
    }
    
    /// @notice Property 37: Input Validation - Add liquidity with zero amount0
    function testProperty_InputValidation_AddLiquidityZeroAmount0() public {
        // Feature: uniswap-v4-orderbook-hook, Property 37: Input Validation
        
        vm.startPrank(user1);
        
        // Deposit tokens first
        hook.deposit(token0, 1000e18);
        hook.deposit(token1, 1000e18);
        
        // Attempt to add liquidity with zero amount0 should revert
        vm.expectRevert(ZeroAmount.selector);
        hook.addLiquidity(-100, 100, 0, 100e18);
        
        vm.stopPrank();
    }
    
    /// @notice Property 37: Input Validation - Add liquidity with zero amount1
    function testProperty_InputValidation_AddLiquidityZeroAmount1() public {
        // Feature: uniswap-v4-orderbook-hook, Property 37: Input Validation
        
        vm.startPrank(user1);
        
        // Deposit tokens first
        hook.deposit(token0, 1000e18);
        hook.deposit(token1, 1000e18);
        
        // Attempt to add liquidity with zero amount1 should revert
        vm.expectRevert(ZeroAmount.selector);
        hook.addLiquidity(-100, 100, 100e18, 0);
        
        vm.stopPrank();
    }
    
    /// @notice Property 37: Input Validation - Remove liquidity with invalid tick range
    function testProperty_InputValidation_RemoveLiquidityInvalidTickRange() public {
        // Feature: uniswap-v4-orderbook-hook, Property 37: Input Validation
        
        vm.startPrank(user1);
        
        // Deposit tokens first
        hook.deposit(token0, 1000e18);
        hook.deposit(token1, 1000e18);
        
        // Add liquidity first
        hook.addLiquidity(-100, 100, 100e18, 100e18);
        
        // Attempt to remove liquidity with invalid tick range should revert
        vm.expectRevert(abi.encodeWithSelector(InvalidInput.selector, "invalid tick range"));
        hook.removeLiquidity(100, 100, 50e18);
        
        vm.stopPrank();
    }
    
    /// @notice Property 37: Input Validation - Remove liquidity with zero amount
    function testProperty_InputValidation_RemoveLiquidityZeroAmount() public {
        // Feature: uniswap-v4-orderbook-hook, Property 37: Input Validation
        
        vm.startPrank(user1);
        
        // Deposit tokens first
        hook.deposit(token0, 1000e18);
        hook.deposit(token1, 1000e18);
        
        // Add liquidity first
        hook.addLiquidity(-100, 100, 100e18, 100e18);
        
        // Attempt to remove zero liquidity should revert
        vm.expectRevert(ZeroAmount.selector);
        hook.removeLiquidity(-100, 100, 0);
        
        vm.stopPrank();
    }
    
    /// @notice Property 37: Input Validation - Fuzz test for deposit amounts
    /// @dev Tests that valid amounts are accepted and invalid amounts are rejected
    function testFuzz_InputValidation_DepositAmount(uint256 amount) public {
        // Feature: uniswap-v4-orderbook-hook, Property 37: Input Validation
        
        vm.startPrank(user1);
        
        if (amount == 0) {
            // Zero amount should revert
            vm.expectRevert(ZeroAmount.selector);
            hook.deposit(token0, amount);
        } else if (amount <= mockToken0.balanceOf(user1)) {
            // Valid amount should succeed
            hook.deposit(token0, amount);
            assertEq(hook.getAvailableBalance(user1, token0), amount);
        }
        // Amounts > balance will revert in transferFrom (not our validation)
        
        vm.stopPrank();
    }
    
    /// @notice Property 37: Input Validation - Fuzz test for order prices
    /// @dev Tests that valid prices are accepted and invalid prices are rejected
    function testFuzz_InputValidation_OrderPrice(uint256 price) public {
        // Feature: uniswap-v4-orderbook-hook, Property 37: Input Validation
        
        // Bound the price to reasonable values to avoid overflow and balance issues
        price = bound(price, 0, 1e30);
        
        vm.startPrank(user1);
        
        if (price == 0) {
            // Zero price should revert - no need to deposit
            vm.expectRevert(ZeroAmount.selector);
            hook.placeOrder(true, price, 100e18);
        } else if (price > 1e30) {
            // Price too high should revert
            vm.expectRevert(abi.encodeWithSelector(InvalidInput.selector, "price out of bounds"));
            hook.placeOrder(true, price, 100e18);
        } else {
            // Valid price - deposit enough tokens
            // For a buy order, we need price * quantity locked
            // Use smaller quantity for large prices to avoid overflow
            uint256 quantity = price > 1e24 ? 1e18 : 100e18;
            uint256 requiredAmount = price * quantity;
            
            // Mint enough tokens
            if (requiredAmount > mockToken1.balanceOf(user1)) {
                mockToken1.mint(user1, requiredAmount);
            }
            hook.deposit(token1, requiredAmount);
            
            // Valid price should succeed
            uint256 orderId = hook.placeOrder(true, price, quantity);
            assertTrue(orderId > 0);
        }
        
        vm.stopPrank();
    }
    
    /// @notice Property 37: Input Validation - Fuzz test for order quantities
    /// @dev Tests that valid quantities are accepted and invalid quantities are rejected
    function testFuzz_InputValidation_OrderQuantity(uint256 quantity) public {
        // Feature: uniswap-v4-orderbook-hook, Property 37: Input Validation
        
        // Bound the quantity to reasonable values to avoid overflow
        quantity = bound(quantity, 0, type(uint128).max);
        
        vm.startPrank(user1);
        
        // Deposit a large amount of tokens first
        mockToken1.mint(user1, 1e31);
        hook.deposit(token1, 1e31);
        
        if (quantity == 0) {
            // Zero quantity should revert
            vm.expectRevert(ZeroAmount.selector);
            hook.placeOrder(true, 1e18, quantity);
        } else if (quantity > 1e30) {
            // Quantity too high should revert
            vm.expectRevert(abi.encodeWithSelector(InvalidInput.selector, "quantity out of bounds"));
            hook.placeOrder(true, 1e18, quantity);
        } else {
            // Valid quantity should succeed
            uint256 orderId = hook.placeOrder(true, 1e18, quantity);
            assertTrue(orderId > 0);
        }
        
        vm.stopPrank();
    }
}

// ============ Mock Contracts ============

/// @notice Mock ERC20 token for testing
contract MockERC20 is IERC20 {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }
    
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (allowance[from][msg.sender] != type(uint256).max) {
            allowance[from][msg.sender] -= amount;
        }
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}

/// @notice Mock PoolManager for testing
contract MockPoolManager {
    // Minimal implementation for testing
}
