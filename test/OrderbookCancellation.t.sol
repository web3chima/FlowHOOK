// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PropertyTestHelper} from "./helpers/PropertyTestHelper.sol";
import {OrderbookEngine} from "../src/OrderbookEngine.sol";
import {Order} from "../src/DataStructures.sol";
import {OrderNotFound, UnauthorizedCancellation, InsufficientBalance} from "../src/Errors.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

/// @title Orderbook Engine Test Contract
/// @notice Concrete implementation of OrderbookEngine for testing
contract OrderbookEngineTestContract is OrderbookEngine {
    constructor(address _token0, address _token1) OrderbookEngine(_token0, _token1) {}

    function placeOrder(bool isBuy, uint256 price, uint256 quantity) external returns (uint256) {
        return _placeOrder(isBuy, price, quantity);
    }

    function matchOrders() external returns (uint256, uint256) {
        return _matchOrders();
    }

    function cancelOrder(uint256 orderId) external {
        _cancelOrder(orderId);
    }
}

/// @title Orderbook Cancellation Tests
/// @notice Unit tests for order cancellation functionality
contract OrderbookCancellationTest is PropertyTestHelper {
    OrderbookEngineTestContract public orderbook;
    ERC20Mock public token0;
    ERC20Mock public token1;

    address public alice = address(0x1);
    address public bob = address(0x2);
    address public charlie = address(0x3);

    uint256 constant INITIAL_MINT = 1000000e18;

    function setUp() public {
        token0 = new ERC20Mock();
        token1 = new ERC20Mock();

        orderbook = new OrderbookEngineTestContract(address(token0), address(token1));

        // Mint tokens to users
        token0.mint(alice, INITIAL_MINT);
        token1.mint(alice, INITIAL_MINT);
        token0.mint(bob, INITIAL_MINT);
        token1.mint(bob, INITIAL_MINT);
        token0.mint(charlie, INITIAL_MINT);
        token1.mint(charlie, INITIAL_MINT);

        // Approve orderbook
        vm.prank(alice);
        token0.approve(address(orderbook), type(uint256).max);
        vm.prank(alice);
        token1.approve(address(orderbook), type(uint256).max);
        vm.prank(bob);
        token0.approve(address(orderbook), type(uint256).max);
        vm.prank(bob);
        token1.approve(address(orderbook), type(uint256).max);
        vm.prank(charlie);
        token0.approve(address(orderbook), type(uint256).max);
        vm.prank(charlie);
        token1.approve(address(orderbook), type(uint256).max);

        // Deposit funds
        vm.prank(alice);
        orderbook.deposit(address(token0), 100000e18);
        vm.prank(alice);
        orderbook.deposit(address(token1), 100000e18);
        vm.prank(bob);
        orderbook.deposit(address(token0), 100000e18);
        vm.prank(bob);
        orderbook.deposit(address(token1), 100000e18);
        vm.prank(charlie);
        orderbook.deposit(address(token0), 100000e18);
        vm.prank(charlie);
        orderbook.deposit(address(token1), 100000e18);
    }

    /// @notice Test cancelling a buy order
    function test_CancelBuyOrder_Success() public {
        uint256 price = 2000e18;
        uint256 quantity = 10e18;

        // Alice places buy order
        vm.prank(alice);
        uint256 orderId = orderbook.placeOrder(true, price, quantity);

        // Check order exists
        assertEq(orderbook.getBuyOrderCount(), 1, "Should have 1 buy order");

        // Get balance before cancellation
        uint256 availableBefore = orderbook.getAvailableBalance(alice, address(token1));
        uint256 lockedBefore = orderbook.getLockedBalance(alice, address(token1));

        // Alice cancels order
        vm.prank(alice);
        orderbook.cancelOrder(orderId);

        // Check order removed from queue
        assertEq(orderbook.getBuyOrderCount(), 0, "Buy order should be removed");

        // Check balance unlocked
        uint256 availableAfter = orderbook.getAvailableBalance(alice, address(token1));
        uint256 lockedAfter = orderbook.getLockedBalance(alice, address(token1));
        uint256 expectedUnlock = (price * quantity) / 1e18;
        assertEq(availableAfter, availableBefore + expectedUnlock, "Available balance should increase");
        assertEq(lockedAfter, lockedBefore - expectedUnlock, "Locked balance should decrease");

        // Check order deleted from storage
        vm.expectRevert(abi.encodeWithSelector(OrderNotFound.selector, orderId));
        orderbook.getOrder(orderId);
    }

    /// @notice Test cancelling a sell order
    function test_CancelSellOrder_Success() public {
        uint256 price = 2000e18;
        uint256 quantity = 10e18;

        // Alice places sell order
        vm.prank(alice);
        uint256 orderId = orderbook.placeOrder(false, price, quantity);

        // Check order exists
        assertEq(orderbook.getSellOrderCount(), 1, "Should have 1 sell order");

        // Get balance before cancellation
        uint256 availableBefore = orderbook.getAvailableBalance(alice, address(token0));
        uint256 lockedBefore = orderbook.getLockedBalance(alice, address(token0));

        // Alice cancels order
        vm.prank(alice);
        orderbook.cancelOrder(orderId);

        // Check order removed from queue
        assertEq(orderbook.getSellOrderCount(), 0, "Sell order should be removed");

        // Check balance unlocked
        uint256 availableAfter = orderbook.getAvailableBalance(alice, address(token0));
        uint256 lockedAfter = orderbook.getLockedBalance(alice, address(token0));
        assertEq(availableAfter, availableBefore + quantity, "Available balance should increase");
        assertEq(lockedAfter, lockedBefore - quantity, "Locked balance should decrease");

        // Check order deleted from storage
        vm.expectRevert(abi.encodeWithSelector(OrderNotFound.selector, orderId));
        orderbook.getOrder(orderId);
    }

    /// @notice Test unauthorized cancellation reverts
    function test_UnauthorizedCancellation_Reverts() public {
        uint256 price = 2000e18;
        uint256 quantity = 10e18;

        // Alice places order
        vm.prank(alice);
        uint256 orderId = orderbook.placeOrder(true, price, quantity);

        // Bob tries to cancel Alice's order
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(UnauthorizedCancellation.selector, bob, orderId));
        orderbook.cancelOrder(orderId);
    }

    /// @notice Test cancelling non-existent order reverts
    function test_CancelNonExistentOrder_Reverts() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(OrderNotFound.selector, 999));
        orderbook.cancelOrder(999);
    }

    /// @notice Test cancelling order from middle of queue
    function test_CancelMiddleOrder_Success() public {
        uint256 price1 = 3000e18;
        uint256 price2 = 2000e18;
        uint256 price3 = 1000e18;
        uint256 quantity = 10e18;

        // Place three buy orders
        vm.prank(alice);
        uint256 order1 = orderbook.placeOrder(true, price1, quantity);

        vm.prank(bob);
        uint256 order2 = orderbook.placeOrder(true, price2, quantity);

        vm.prank(charlie);
        uint256 order3 = orderbook.placeOrder(true, price3, quantity);

        // Verify order
        assertEq(orderbook.getBuyOrderCount(), 3, "Should have 3 buy orders");

        // Cancel middle order
        vm.prank(bob);
        orderbook.cancelOrder(order2);

        // Check queue updated correctly
        assertEq(orderbook.getBuyOrderCount(), 2, "Should have 2 buy orders");

        uint256[] memory buyOrders = orderbook.getBuyOrderIds();
        assertEq(buyOrders[0], order1, "First order should be order1");
        assertEq(buyOrders[1], order3, "Second order should be order3");
    }

    /// @notice Test cancelling multiple orders
    function test_CancelMultipleOrders_Success() public {
        uint256 price = 2000e18;
        uint256 quantity = 10e18;

        // Alice places multiple orders
        vm.prank(alice);
        uint256 order1 = orderbook.placeOrder(true, price, quantity);

        vm.prank(alice);
        uint256 order2 = orderbook.placeOrder(false, price, quantity);

        assertEq(orderbook.getBuyOrderCount(), 1, "Should have 1 buy order");
        assertEq(orderbook.getSellOrderCount(), 1, "Should have 1 sell order");

        // Cancel both orders
        vm.prank(alice);
        orderbook.cancelOrder(order1);

        vm.prank(alice);
        orderbook.cancelOrder(order2);

        assertEq(orderbook.getBuyOrderCount(), 0, "Should have 0 buy orders");
        assertEq(orderbook.getSellOrderCount(), 0, "Should have 0 sell orders");
    }
}
