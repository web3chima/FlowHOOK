// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PackedKyleState, PackedVolatilityState, PackedFeeState, KyleState, VolatilityState} from "../DataStructures.sol";

/// @title Storage Optimization Library
/// @notice Library for packing and unpacking storage-optimized structs
/// @dev Reduces storage costs by packing multiple values into single slots
library StorageOptimization {
    /// @notice Pack KyleState into PackedKyleState for storage
    /// @param state The full KyleState
    /// @return packed The packed state
    function packKyleState(KyleState memory state) internal pure returns (PackedKyleState memory packed) {
        packed = PackedKyleState({
            lambda: uint64(state.lambda / 1e12), // Scale down for storage
            cumulativeFlow: int64(state.cumulativeFlow / 1e12), // Scale down for storage
            baseDepth: uint64(state.baseDepth / 1e12), // Scale down for storage
            effectiveDepth: uint64(state.effectiveDepth / 1e12) // Scale down for storage
        });
    }

    /// @notice Unpack PackedKyleState for use
    /// @param packed The packed state
    /// @param currentBlock The current block number
    /// @return state The full KyleState
    function unpackKyleState(PackedKyleState memory packed, uint256 currentBlock) internal pure returns (KyleState memory state) {
        state = KyleState({
            lambda: uint256(packed.lambda) * 1e12, // Scale up from storage
            cumulativeFlow: int256(packed.cumulativeFlow) * 1e12, // Scale up from storage
            lastUpdateBlock: currentBlock,
            baseDepth: uint256(packed.baseDepth) * 1e12, // Scale up from storage
            effectiveDepth: uint256(packed.effectiveDepth) * 1e12 // Scale up from storage
        });
    }

    /// @notice Pack VolatilityState into PackedVolatilityState for storage
    /// @param state The full VolatilityState
    /// @return packed The packed state
    function packVolatilityState(VolatilityState memory state) internal pure returns (PackedVolatilityState memory packed) {
        packed = PackedVolatilityState({
            baseVolatility: uint64(state.baseVolatility / 1e12), // Scale down for storage
            longOI: uint64(state.longOI / 1e12), // Scale down for storage
            shortOI: uint64(state.shortOI / 1e12), // Scale down for storage
            effectiveVolatility: uint64(state.effectiveVolatility / 1e12) // Scale down for storage
        });
    }

    /// @notice Unpack PackedVolatilityState for use
    /// @param packed The packed state
    /// @param currentBlock The current block number
    /// @return state The full VolatilityState
    function unpackVolatilityState(PackedVolatilityState memory packed, uint256 currentBlock) internal pure returns (VolatilityState memory state) {
        state = VolatilityState({
            baseVolatility: uint256(packed.baseVolatility) * 1e12, // Scale up from storage
            longOI: uint256(packed.longOI) * 1e12, // Scale up from storage
            shortOI: uint256(packed.shortOI) * 1e12, // Scale up from storage
            effectiveVolatility: uint256(packed.effectiveVolatility) * 1e12, // Scale up from storage
            lastUpdateBlock: currentBlock
        });
    }

    /// @notice Batch update multiple storage slots efficiently
    /// @dev Uses assembly for gas-efficient batch updates
    /// @param slot1 First storage slot
    /// @param value1 First value
    /// @param slot2 Second storage slot
    /// @param value2 Second value
    function batchStorageUpdate(
        bytes32 slot1,
        uint256 value1,
        bytes32 slot2,
        uint256 value2
    ) internal {
        assembly {
            sstore(slot1, value1)
            sstore(slot2, value2)
        }
    }

    /// @notice Batch update three storage slots efficiently
    /// @param slot1 First storage slot
    /// @param value1 First value
    /// @param slot2 Second storage slot
    /// @param value2 Second value
    /// @param slot3 Third storage slot
    /// @param value3 Third value
    function batchStorageUpdate3(
        bytes32 slot1,
        uint256 value1,
        bytes32 slot2,
        uint256 value2,
        bytes32 slot3,
        uint256 value3
    ) internal {
        assembly {
            sstore(slot1, value1)
            sstore(slot2, value2)
            sstore(slot3, value3)
        }
    }

    /// @notice Cache storage reads in memory for repeated access
    /// @param slot The storage slot to read
    /// @return value The cached value
    function cacheStorageRead(bytes32 slot) internal view returns (uint256 value) {
        assembly {
            value := sload(slot)
        }
    }

    /// @notice Efficiently pack two uint128 values into one uint256
    /// @param a First uint128 value
    /// @param b Second uint128 value
    /// @return packed The packed uint256
    function packUint128(uint128 a, uint128 b) internal pure returns (uint256 packed) {
        packed = (uint256(a) << 128) | uint256(b);
    }

    /// @notice Unpack uint256 into two uint128 values
    /// @param packed The packed uint256
    /// @return a First uint128 value
    /// @return b Second uint128 value
    function unpackUint128(uint256 packed) internal pure returns (uint128 a, uint128 b) {
        a = uint128(packed >> 128);
        b = uint128(packed);
    }

    /// @notice Pack four uint64 values into one uint256
    /// @param a First uint64 value
    /// @param b Second uint64 value
    /// @param c Third uint64 value
    /// @param d Fourth uint64 value
    /// @return packed The packed uint256
    function packUint64x4(uint64 a, uint64 b, uint64 c, uint64 d) internal pure returns (uint256 packed) {
        packed = (uint256(a) << 192) | (uint256(b) << 128) | (uint256(c) << 64) | uint256(d);
    }

    /// @notice Unpack uint256 into four uint64 values
    /// @param packed The packed uint256
    /// @return a First uint64 value
    /// @return b Second uint64 value
    /// @return c Third uint64 value
    /// @return d Fourth uint64 value
    function unpackUint64x4(uint256 packed) internal pure returns (uint64 a, uint64 b, uint64 c, uint64 d) {
        a = uint64(packed >> 192);
        b = uint64(packed >> 128);
        c = uint64(packed >> 64);
        d = uint64(packed);
    }
}
