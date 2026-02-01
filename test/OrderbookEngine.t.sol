// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {PropertyTestHelper} from "./helpers/PropertyTestHelper.sol";
import {OrderbookEngine} from "../src/OrderbookEngine.sol";
import {Order} from "../src/DataStructures.sol";
import {OrderNotFound, UnauthorizedCancellation, InvalidInput, ZeroAmount} from "../src/Errors.sol";
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

/// @title Orderbook Engine Tests
/// @notice Property-based and unit tests for orderbook engine
contract OrderbookEngineTest is PropertyTestHelper {
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

    /// @notice Property 1: Orderbook Price-Time Priority
    /// @dev For any sequence of orders added to the orderbook, the buy queue SHALL be sorted
    ///      in descending price order (highest first), and within the same price, by timestamp
    ///      (earliest first). The sell queue SHALL be sorted in ascending price order (lowest first),
    ///      and within the same price, by timestamp (earliest first).
    /// Feature: uniswap-v4-orderbook-hook, Property 1: Orderbook Price-Time Priority
    /// Validates: Requirements 2.1, 5.2
    function testProperty_OrderbookPriceTimePriority(uint8 numOrders) public {
        numOrders = uint8(bound(numOrders, 1, 20)); // Limit to reasonable number

        // Place random orders
        for (uint8 i = 0; i < numOrders; i++) {
            bool isBuy = i % 2 == 0;
            // Bound prices to reasonable range to avoid overflow
            uint256 price = bound(uint256(keccak256(abi.encodePacked(i, "price"))), 100e18, 1000e18);
            uint256 quantity = bound(uint256(keccak256(abi.encodePacked(i, "quantity"))), 1e18, 10e18);

            address trader = i % 3 == 0 ? alice : (i % 3 == 1 ? bob : charlie);

            vm.prank(trader);
            orderbook.placeOrder(isBuy, price, quantity);

            // Small time advancement to ensure different timestamps
            vm.warp(block.timestamp + 1);
        }

        // Verify buy queue is sorted descending by price, then by time
        uint256[] memory buyOrders = orderbook.getBuyOrderIds();
        for (uint256 i = 1; i < buyOrders.length; i++) {
            Order memory prev = orderbook.getOrder(buyOrders[i - 1]);
            Order memory curr = orderbook.getOrder(buyOrders[i]);

            // Price should be descending (prev >= curr)
            // If prices equal, timestamp should be ascending (prev <= curr)
            assertTrue(
                prev.price > curr.price || (prev.price == curr.price && prev.timestamp <= curr.timestamp),
                "Buy queue not sorted correctly"
            );
        }

        // Verify sell queue is sorted ascending by price, then by time
        uint256[] memory sellOrders = orderbook.getSellOrderIds();
        for (uint256 i = 1; i < sellOrders.length; i++) {
            Order memory prev = orderbook.getOrder(sellOrders[i - 1]);
            Order memory curr = orderbook.getOrder(sellOrders[i]);

            // Price should be ascending (prev <= curr)
            // If prices equal, timestamp should be ascending (prev <= curr)
            assertTrue(
                prev.price < curr.price || (prev.price == curr.price && prev.timestamp <= curr.timestamp),
                "Sell queue not sorted correctly"
            );
        }
    }

    /// @notice Test placing a single buy order
    function test_PlaceSingleBuyOrder_Success() public {
        uint256 price = 2000e18;
        uint256 quantity = 10e18;

        vm.prank(alice);
        uint256 orderId = orderbook.placeOrder(true, price, quantity);

        assertEq(orderId, 1, "Order ID should be 1");

        Order memory order = orderbook.getOrder(orderId);
        assertEq(order.orderId, orderId, "Order ID mismatch");
        assertEq(order.trader, alice, "Trader mismatch");
        assertTrue(order.isBuy, "Should be buy order");
        assertEq(order.price, price, "Price mismatch");
        assertEq(order.quantity, quantity, "Quantity mismatch");

        uint256[] memory buyOrders = orderbook.getBuyOrderIds();
        assertEq(buyOrders.length, 1, "Should have 1 buy order");
        assertEq(buyOrders[0], orderId, "Buy order ID mismatch");
    }

    /// @notice Test placing a single sell order
    function test_PlaceSingleSellOrder_Success() public {
        uint256 price = 2000e18;
        uint256 quantity = 10e18;

        vm.prank(alice);
        uint256 orderId = orderbook.placeOrder(false, price, quantity);

        assertEq(orderId, 1, "Order ID should be 1");

        Order memory order = orderbook.getOrder(orderId);
        assertEq(order.orderId, orderId, "Order ID mismatch");
        assertEq(order.trader, alice, "Trader mismatch");
        assertFalse(order.isBuy, "Should be sell order");
        assertEq(order.price, price, "Price mismatch");
        assertEq(order.quantity, quantity, "Quantity mismatch");

        uint256[] memory sellOrders = orderbook.getSellOrderIds();
        assertEq(sellOrders.length, 1, "Should have 1 sell order");
        assertEq(sellOrders[0], orderId, "Sell order ID mismatch");
    }

    /// @notice Test buy orders are sorted descending by price
    function test_BuyOrdersSortedDescending_Success() public {
        vm.prank(alice);
        uint256 order1 = orderbook.placeOrder(true, 2000e18, 10e18);

        vm.prank(bob);
        uint256 order2 = orderbook.placeOrder(true, 3000e18, 10e18);

        vm.prank(charlie);
        uint256 order3 = orderbook.placeOrder(true, 2500e18, 10e18);

        uint256[] memory buyOrders = orderbook.getBuyOrderIds();
        assertEq(buyOrders.length, 3, "Should have 3 buy orders");

        // Should be sorted: 3000, 2500, 2000
        assertEq(buyOrders[0], order2, "Highest price should be first");
        assertEq(buyOrders[1], order3, "Middle price should be second");
        assertEq(buyOrders[2], order1, "Lowest price should be third");
    }

    /// @notice Test sell orders are sorted ascending by price
    function test_SellOrdersSortedAscending_Success() public {
        vm.prank(alice);
        uint256 order1 = orderbook.placeOrder(false, 2000e18, 10e18);

        vm.prank(bob);
        uint256 order2 = orderbook.placeOrder(false, 3000e18, 10e18);

        vm.prank(charlie);
        uint256 order3 = orderbook.placeOrder(false, 2500e18, 10e18);

        uint256[] memory sellOrders = orderbook.getSellOrderIds();
        assertEq(sellOrders.length, 3, "Should have 3 sell orders");

        // Should be sorted: 2000, 2500, 3000
        assertEq(sellOrders[0], order1, "Lowest price should be first");
        assertEq(sellOrders[1], order3, "Middle price should be second");
        assertEq(sellOrders[2], order2, "Highest price should be third");
    }

    /// @notice Test orders with same price are sorted by timestamp
    function test_SamePriceSortedByTimestamp_Success() public {
        uint256 price = 2000e18;

        vm.prank(alice);
        uint256 order1 = orderbook.placeOrder(true, price, 10e18);

        vm.warp(block.timestamp + 10);

        vm.prank(bob);
        uint256 order2 = orderbook.placeOrder(true, price, 10e18);

        vm.warp(block.timestamp + 10);

        vm.prank(charlie);
        uint256 order3 = orderbook.placeOrder(true, price, 10e18);

        uint256[] memory buyOrders = orderbook.getBuyOrderIds();
        assertEq(buyOrders.length, 3, "Should have 3 buy orders");

        // Should be sorted by timestamp: order1, order2, order3
        assertEq(buyOrders[0], order1, "Earliest order should be first");
        assertEq(buyOrders[1], order2, "Middle order should be second");
        assertEq(buyOrders[2], order3, "Latest order should be third");
    }

    /// @notice Test zero price reverts
    function test_ZeroPrice_Reverts() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(InvalidInput.selector, "price"));
        orderbook.placeOrder(true, 0, 10e18);
    }

    /// @notice Test zero quantity reverts
    function test_ZeroQuantity_Reverts() public {
        vm.prank(alice);
        vm.expectRevert(ZeroAmount.selector);
        orderbook.placeOrder(true, 2000e18, 0);
    }

    /// @notice Test getting non-existent order reverts
    function test_GetNonExistentOrder_Reverts() public {
        vm.expectRevert(abi.encodeWithSelector(OrderNotFound.selector, 999));
        orderbook.getOrder(999);
    }
}

/// @title Orderbook Matching Tests
/// @notice Tests for order matching functionality
contract OrderbookMatchingTest is PropertyTestHelper {
    OrderbookEngineTestContract public orderbook;
    ERC20Mock public token0;
    ERC20Mock public token1;

    address public alice = address(0x1);
    address public bob = address(0x2);

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

        // Approve orderbook
        vm.prank(alice);
        token0.approve(address(orderbook), type(uint256).max);
        vm.prank(alice);
        token1.approve(address(orderbook), type(uint256).max);
        vm.prank(bob);
        token0.approve(address(orderbook), type(uint256).max);
        vm.prank(bob);
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
    }

    /// @notice Property 3: Maker Price Execution
    /// @dev For any pair of matched orders, the execution price SHALL equal the maker order's price
    ///      (the order that was placed first).
    /// Feature: uniswap-v4-orderbook-hook, Property 3: Maker Price Execution
    /// Validates: Requirements 5.4
    function testProperty_MakerPriceExecution(uint256 buyPrice, uint256 sellPrice) public {
        // Bound prices to reasonable ranges first
        buyPrice = bound(buyPrice, 1000e18, 10000e18);
        sellPrice = bound(sellPrice, 1000e18, 10000e18);
        
        // Ensure prices can match (buy price >= sell price)
        if (buyPrice < sellPrice) {
            // Swap them to ensure matching condition
            (buyPrice, sellPrice) = (sellPrice, buyPrice);
        }

        uint256 quantity = 10e18;

        // Place sell order first (maker)
        vm.prank(alice);
        uint256 sellOrderId = orderbook.placeOrder(false, sellPrice, quantity);

        vm.warp(block.timestamp + 10);

        // Place buy order second (taker)
        vm.prank(bob);
        uint256 buyOrderId = orderbook.placeOrder(true, buyPrice, quantity);

        // Record event to check execution price
        vm.recordLogs();

        // Match orders
        orderbook.matchOrders();

        // Check the OrderMatched event
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool foundMatchEvent = false;
        uint256 executionPrice = 0;

        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("OrderMatched(uint256,uint256,uint256,uint256,uint256)")) {
                // buyOrderId and sellOrderId are indexed, so they're in topics
                uint256 buyId = uint256(logs[i].topics[1]);
                uint256 sellId = uint256(logs[i].topics[2]);
                
                // price, quantity, timestamp are in data
                (uint256 price,,) = abi.decode(logs[i].data, (uint256, uint256, uint256));

                if (buyId == buyOrderId && sellId == sellOrderId) {
                    foundMatchEvent = true;
                    executionPrice = price;
                    break;
                }
            }
        }

        assertTrue(foundMatchEvent, "OrderMatched event not found");

        // Execution price should be the maker's price (sell order was placed first)
        assertEq(executionPrice, sellPrice, "Execution price should equal maker price");
    }

    /// @notice Test simple order matching
    function test_SimpleOrderMatch_Success() public {
        uint256 price = 2000e18;
        uint256 quantity = 10e18;

        // Alice places sell order
        vm.prank(alice);
        orderbook.placeOrder(false, price, quantity);

        // Bob places buy order
        vm.prank(bob);
        orderbook.placeOrder(true, price, quantity);

        // Match orders
        (uint256 matchedVolume, uint256 avgPrice) = orderbook.matchOrders();

        assertEq(matchedVolume, quantity, "Matched volume should equal order quantity");
        assertEq(avgPrice, price, "Average price should equal order price");

        // Both orders should be removed
        assertEq(orderbook.getBuyOrderCount(), 0, "Buy queue should be empty");
        assertEq(orderbook.getSellOrderCount(), 0, "Sell queue should be empty");
    }

    /// @notice Test no match when buy price < sell price
    function test_NoMatchWhenPricesDontOverlap_Success() public {
        // Alice places sell order at 3000
        vm.prank(alice);
        orderbook.placeOrder(false, 3000e18, 10e18);

        // Bob places buy order at 2000
        vm.prank(bob);
        orderbook.placeOrder(true, 2000e18, 10e18);

        // Match orders
        (uint256 matchedVolume,) = orderbook.matchOrders();

        assertEq(matchedVolume, 0, "No volume should be matched");

        // Both orders should remain
        assertEq(orderbook.getBuyOrderCount(), 1, "Buy order should remain");
        assertEq(orderbook.getSellOrderCount(), 1, "Sell order should remain");
    }

    /// @notice Property 4: Partial Fill Support
    /// @dev For any two matching orders with different quantities, the smaller order SHALL be filled
    ///      completely, and the larger order SHALL have its quantity reduced by the filled amount.
    /// Feature: uniswap-v4-orderbook-hook, Property 4: Partial Fill Support
    /// Validates: Requirements 5.5
    function testProperty_PartialFillSupport(uint256 buyQty, uint256 sellQty) public {
        buyQty = bound(buyQty, 1e18, 50e18);
        sellQty = bound(sellQty, 1e18, 50e18);

        // Ensure quantities are different
        vm.assume(buyQty != sellQty);

        uint256 price = 2000e18;

        // Place sell order
        vm.prank(alice);
        uint256 sellOrderId = orderbook.placeOrder(false, price, sellQty);

        // Place buy order
        vm.prank(bob);
        uint256 buyOrderId = orderbook.placeOrder(true, price, buyQty);

        // Match orders
        (uint256 matchedVolume,) = orderbook.matchOrders();

        // Matched volume should be the minimum of the two quantities
        uint256 expectedMatch = buyQty < sellQty ? buyQty : sellQty;
        assertEq(matchedVolume, expectedMatch, "Matched volume should be minimum of both orders");

        // Check which order should be completely filled and which should remain
        if (buyQty < sellQty) {
            // Buy order completely filled, sell order partially filled
            assertEq(orderbook.getBuyOrderCount(), 0, "Buy order should be removed");
            assertEq(orderbook.getSellOrderCount(), 1, "Sell order should remain");

            Order memory remainingSell = orderbook.getOrder(sellOrderId);
            assertEq(remainingSell.quantity, sellQty - buyQty, "Sell order quantity should be reduced");
        } else {
            // Sell order completely filled, buy order partially filled
            assertEq(orderbook.getSellOrderCount(), 0, "Sell order should be removed");
            assertEq(orderbook.getBuyOrderCount(), 1, "Buy order should remain");

            Order memory remainingBuy = orderbook.getOrder(buyOrderId);
            assertEq(remainingBuy.quantity, buyQty - sellQty, "Buy order quantity should be reduced");
        }
    }

    /// @notice Test partial fill with larger buy order
    function test_PartialFillLargerBuy_Success() public {
        uint256 price = 2000e18;
        uint256 sellQty = 10e18;
        uint256 buyQty = 20e18;

        // Alice places sell order
        vm.prank(alice);
        uint256 sellOrderId = orderbook.placeOrder(false, price, sellQty);

        // Bob places buy order
        vm.prank(bob);
        uint256 buyOrderId = orderbook.placeOrder(true, price, buyQty);

        // Match orders
        (uint256 matchedVolume,) = orderbook.matchOrders();

        assertEq(matchedVolume, sellQty, "Should match sell quantity");

        // Sell order should be removed
        assertEq(orderbook.getSellOrderCount(), 0, "Sell order should be removed");

        // Buy order should remain with reduced quantity
        assertEq(orderbook.getBuyOrderCount(), 1, "Buy order should remain");
        Order memory remainingBuy = orderbook.getOrder(buyOrderId);
        assertEq(remainingBuy.quantity, buyQty - sellQty, "Buy order quantity should be reduced");
    }

    /// @notice Test partial fill with larger sell order
    function test_PartialFillLargerSell_Success() public {
        uint256 price = 2000e18;
        uint256 sellQty = 20e18;
        uint256 buyQty = 10e18;

        // Alice places sell order
        vm.prank(alice);
        uint256 sellOrderId = orderbook.placeOrder(false, price, sellQty);

        // Bob places buy order
        vm.prank(bob);
        uint256 buyOrderId = orderbook.placeOrder(true, price, buyQty);

        // Match orders
        (uint256 matchedVolume,) = orderbook.matchOrders();

        assertEq(matchedVolume, buyQty, "Should match buy quantity");

        // Buy order should be removed
        assertEq(orderbook.getBuyOrderCount(), 0, "Buy order should be removed");

        // Sell order should remain with reduced quantity
        assertEq(orderbook.getSellOrderCount(), 1, "Sell order should remain");
        Order memory remainingSell = orderbook.getOrder(sellOrderId);
        assertEq(remainingSell.quantity, sellQty - buyQty, "Sell order quantity should be reduced");
    }
}
