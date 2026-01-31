// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

/// @title Property Test Helper
/// @notice Base contract for property-based testing with common utilities
abstract contract PropertyTestHelper is Test {
    uint256 internal constant MIN_PROPERTY_RUNS = 100;

    function boundValue(uint256 value, uint256 min, uint256 max) internal pure returns (uint256) {
        return bound(value, min, max);
    }

    function randomNonZeroAddress(uint256 seed) internal pure returns (address) {
        address addr = address(uint160(uint256(keccak256(abi.encodePacked(seed)))));
        if (addr == address(0)) {
            addr = address(1);
        }
        return addr;
    }

    function randomPrice(uint256 seed) internal pure returns (uint256) {
        return bound(seed, 1e15, 1000e18);
    }

    function randomQuantity(uint256 seed) internal pure returns (uint256) {
        return bound(seed, 1e16, 10000e18);
    }

    function approxEqual(uint256 a, uint256 b, uint256 tolerance) internal pure returns (bool) {
        if (a > b) {
            return a - b <= tolerance;
        } else {
            return b - a <= tolerance;
        }
    }

    function percentDiff(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0 && b == 0) return 0;
        if (a == 0 || b == 0) return 100e18;
        
        uint256 diff = a > b ? a - b : b - a;
        uint256 base = a > b ? a : b;
        return (diff * 100e18) / base;
    }
}
