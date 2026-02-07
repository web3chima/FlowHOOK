// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {OrderbookEngine} from "../src/OrderbookEngine.sol";
import {CustodyManager} from "../src/CustodyManager.sol";
import {Order} from "../src/DataStructures.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {PropertyTestHelper} from "./helpers/PropertyTestHelper.sol";

/// @title Orderbook Engine Test Contract
/// @notice Concrete implementation of OrderbookEngine for testing
contract OrderbookEngineTestContract is OrderbookEngine {
    constructor(address _token0, address _token1) CustodyManager(_token0, _token1) {}

    function placeOrder(bool isBuy, uint256 price, uint256 quantity) external returns (uint256) {
        return _placeOrder(isBuy, price, quantity);
    }

    function matchOrders() external returns (uint256 matchedVolume, uint256 avgPrice) {
        return _matchOrders();
    }

    function getOrderbookDepth() external view returns (uint256 buyDepth, uint256 sellDepth) {
        return (buyOrderIds.length, sellOrderIds.length);
    }

    function getBuyOrderId(uint256 index) external view returns (uint256) {
        return buyOrderIds[index];
    }

    function getSellOrderId(uint256 index) external view returns (uint256) {
        return sellOrderIds[index];
    }
}

/// @title Multi-Order Atomic Processing Tests
/// @notice Property-based tests for Property 50: Multi-Order Atomic Processing
/// @dev **Validates: Requirements 14.5**
contract MultiOrderAtomicTest is PropertyTestHelper {
    OrderbookEngineTestContract public orderbook;
    ERC20Mock public token0;
    ERC20Mock public token1;

    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public user3 = address(0x3);

    uint256 constant INITIAL_BALANCE = 1000000 * 1e18;
    uint256 constant DEPOSIT_AMOUNT = 100000 * 1e18;

    function setUp() public {
        token0 = new ERC20Mock();
        token1 = new ERC20Mock();

        orderbook = new OrderbookEngineTestContract(address(token0), address(token1));

        // Setup users
        token0.mint(user1, INITIAL_BALANCE);
        token1.mint(user1, INITIAL_BALANCE);
        token0.mint(user2, INITIAL_BALANCE);
        token1.mint(user2, INITIAL_BALANCE);
        token0.mint(user3, INITIAL_BALANCE);
        token1.mint(user3, INITIAL_BALANCE);

        // Approve orderbook
        vm.startPrank(user1);
        token0.approve(address(orderbook), type(uint256).max);
        token1.approve(address(orderbook), type(uint256).max);
        orderbook.deposit(address(token0), DEPOSIT_AMOUNT);
        orderbook.deposit(address(token1), DEPOSIT_AMOUNT);
        vm.stopPrank();

        vm.startPrank(user2);
        token0.approve(address(orderbook), type(uint256).max);
        token1.approve(address(orderbook), type(uint256).max);
        orderbook.deposit(address(token0), DEPOSIT_AMOUNT);
        orderbook.deposit(address(token1), DEPOSIT_AMOUNT);
        vm.stopPrank();

        vm.startPrank(user3);
        token0.approve(address(orderbook), type(uint256).max);
        token1.approve(address(orderbook), type(uint256).max);
        orderbook.deposit(address(token0), DEPOSIT_AMOUNT);
        orderbook.deposit(address(token1), DEPOSIT_AMOUNT);
        vm.stopPrank();
    }

    /// @notice Property 50: Multi-Order Atomic Processing
    /// @dev For any set of compatible orders, all matches SHALL occur in a single transaction
    /// **Validates: Requirements 14.5**
    function testProperty_MultiOrderAtomicProcessing(
        uint256 numBuyOrders,
        uint256 numSellOrders,
        uint256 seed
    ) public {
        // Bound inputs
        numBuyOrders = bound(numBuyOrders, 1, 5);
        numSellOrders = bound(numSellOrders, 1, 5);

        // Place multiple buy orders
        vm.startPrank(user1);
        for (uint256 i = 0; i < numBuyOrders; i++) {
            uint256 price = 1e18 + (seed % 1000) * 1e15; // Price between 1.0 and 2.0
            uint256 quantity = 100 * 1e18 + (seed % 100) * 1e18;
            orderbook.placeOrder(true, price, quantity);
            seed = uint256(keccak256(abi.encode(seed)));
        }
        vm.stopPrank();

        // Place multiple sell orders
        vm.startPrank(user2);
        for (uint256 i = 0; i < numSellOrders; i++) {
            uint256 price = 1e18 + (seed % 1000) * 1e15; // Price between 1.0 and 2.0
            uint256 quantity = 100 * 1e18 + (seed % 100) * 1e18;
            orderbook.placeOrder(false, price, quantity);
            seed = uint256(keccak256(abi.encode(seed)));
        }
        vm.stopPrank();

        // Get orderbook state before matching
        (uint256 buyDepthBefore, uint256 sellDepthBefore) = orderbook.getOrderbookDepth();

        // Match orders in a single transaction
        (uint256 matchedVolume, uint256 avgPrice) = orderbook.matchOrders();

        // Get orderbook state after matching
        (uint256 buyDepthAfter, uint256 sellDepthAfter) = orderbook.getOrderbookDepth();

        // Property: All compatible orders should be matched in single transaction
        // Either all buy orders matched, all sell orders matched, or no more compatible orders
        if (matchedVolume > 0) {
            // Some orders were matched
            assertTrue(
                buyDepthAfter < buyDepthBefore || sellDepthAfter < sellDepthBefore,
                "At least one side should have fewer orders after matching"
            );

            // If there are still orders on both sides, they must be incompatible
            if (buyDepthAfter > 0 && sellDepthAfter > 0) {
                // Get best bid and ask
                Order memory bestBid = orderbook.getOrder(orderbook.getBuyOrderId(0));
                Order memory bestAsk = orderbook.getOrder(orderbook.getSellOrderId(0));

                // They should not be compatible (bid < ask)
                assertLt(
                    bestBid.price,
                    bestAsk.price,
                    "Remaining orders should be incompatible"
                );
            }
        }
    }

    /// @notice Test that multiple orders match atomically in a single call
    function test_MultipleOrdersMatchInSingleTransaction() public {
        // Place 3 buy orders at different prices
        vm.startPrank(user1);
        orderbook.placeOrder(true, 1.2e18, 100 * 1e18); // Highest bid
        orderbook.placeOrder(true, 1.1e18, 100 * 1e18);
        orderbook.placeOrder(true, 1.0e18, 100 * 1e18); // Lowest bid
        vm.stopPrank();

        // Place 1 large sell order that can match all
        vm.startPrank(user2);
        orderbook.placeOrder(false, 1.0e18, 300 * 1e18);
        vm.stopPrank();

        // Get initial state
        (uint256 buyDepthBefore,) = orderbook.getOrderbookDepth();
        assertEq(buyDepthBefore, 3, "Should have 3 buy orders");

        // Match orders - should match all 3 buy orders in single transaction
        (uint256 matchedVolume,) = orderbook.matchOrders();

        // Verify all buy orders were matched
        (uint256 buyDepthAfter, uint256 sellDepthAfter) = orderbook.getOrderbookDepth();
        assertEq(buyDepthAfter, 0, "All buy orders should be matched");
        assertEq(sellDepthAfter, 0, "Sell order should be fully filled");
        assertEq(matchedVolume, 300 * 1e18, "Should match total volume");
    }

    /// @notice Test that partial fills work correctly in atomic processing
    function test_PartialFillsInAtomicProcessing() public {
        // Place 2 buy orders
        vm.startPrank(user1);
        orderbook.placeOrder(true, 1.1e18, 100 * 1e18);
        orderbook.placeOrder(true, 1.0e18, 100 * 1e18);
        vm.stopPrank();

        // Place 1 sell order that partially fills
        vm.startPrank(user2);
        orderbook.placeOrder(false, 1.0e18, 150 * 1e18);
        vm.stopPrank();

        // Match orders
        (uint256 matchedVolume,) = orderbook.matchOrders();

        // Verify partial fill
        (uint256 buyDepthAfter, uint256 sellDepthAfter) = orderbook.getOrderbookDepth();
        assertEq(buyDepthAfter, 1, "One buy order should remain partially filled");
        assertEq(sellDepthAfter, 0, "Sell order should be fully filled");
        assertEq(matchedVolume, 150 * 1e18, "Should match available volume");
        
        // Verify remaining buy order has correct quantity
        Order memory remainingOrder = orderbook.getOrder(orderbook.getBuyOrderId(0));
        assertEq(remainingOrder.quantity, 50 * 1e18, "Remaining order should have 50 units");
    }

    /// @notice Test that atomicity is maintained even with many orders
    function test_AtomicityWithManyOrders() public {
        // Place 10 buy orders
        vm.startPrank(user1);
        for (uint256 i = 0; i < 10; i++) {
            orderbook.placeOrder(true, 1e18 + i * 1e16, 50 * 1e18);
        }
        vm.stopPrank();

        // Place 10 sell orders
        vm.startPrank(user2);
        for (uint256 i = 0; i < 10; i++) {
            orderbook.placeOrder(false, 1e18 + i * 1e16, 50 * 1e18);
        }
        vm.stopPrank();

        // Get snapshot before matching
        uint256 snapshotId = vm.snapshot();

        // Match orders
        (uint256 matchedVolume,) = orderbook.matchOrders();

        // Verify some orders were matched
        assertGt(matchedVolume, 0, "Should match some volume");

        // Revert to snapshot
        vm.revertTo(snapshotId);

        // Try matching again - should get same result (demonstrating atomicity)
        (uint256 matchedVolume2,) = orderbook.matchOrders();
        assertEq(matchedVolume, matchedVolume2, "Matching should be deterministic and atomic");
    }
}
