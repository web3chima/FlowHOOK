// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IFlowHookEngine Interface
/// @notice Common interface for all FlowHook engine modules
interface IFlowHookEngine {
    /// @notice Execute a trade on the engine
    /// @param size The trade size
    /// @param isLong True for long, false for short
    /// @return executionPrice The execution price
    /// @return priceImpact The price impact
    function executeTrade(uint256 size, bool isLong) 
        external 
        returns (uint256 executionPrice, uint256 priceImpact);
    
    /// @notice Get current price from the engine
    /// @return price The current price
    function getPrice() external view returns (uint256 price);
    
    /// @notice Check if the engine is initialized
    /// @return True if initialized
    function isInitialized() external view returns (bool);
}

/// @title IVAMMEngine Interface
/// @notice Interface for VAMM engine with P = K × Q^(-2) curve
interface IVAMMEngine is IFlowHookEngine {
    /// @notice Initialize the VAMM curve
    /// @param initialPrice Initial price in USD (scaled by 1e18)
    /// @param initialQuantity Initial vBTC quantity in pool (scaled by 1e18)
    function initialize(uint256 initialPrice, uint256 initialQuantity) external;
    
    /// @notice Get the full curve state
    /// @return k Pool constant K
    /// @return q Current vBTC quantity
    /// @return price Current price P = K / Q²
    /// @return sensitivity Price sensitivity |dP/dQ|
    function getCurveState() external view returns (
        uint256 k,
        uint256 q,
        uint256 price,
        uint256 sensitivity
    );
    
    /// @notice Get open interest breakdown
    /// @return longOI Total long open interest
    /// @return shortOI Total short open interest
    /// @return netOI Net open interest (long - short)
    function getOpenInterest() external view returns (
        uint256 longOI,
        uint256 shortOI,
        int256 netOI
    );
    
    /// @notice Simulate a trade without executing
    /// @param size Trade size
    /// @param isLong Trade direction
    /// @return price Simulated execution price
    /// @return impact Simulated price impact
    function simulateTrade(uint256 size, bool isLong) 
        external view 
        returns (uint256 price, uint256 impact);
    
    /// @notice Close a position
    /// @param size Position size to close
    /// @param isLong True if closing a long position
    /// @return executionPrice The closing price
    function closePosition(uint256 size, bool isLong) 
        external 
        returns (uint256 executionPrice);
}

/// @title ILOBEngine Interface  
/// @notice Interface for Limit Order Book engine
interface ILOBEngine is IFlowHookEngine {
    struct LOBOrder {
        uint256 id;
        uint256 price;
        uint256 quantity;
        bool isBuy;
        address trader;
        bool active;
    }

    /// @notice Place a limit order
    /// @param price Limit price
    /// @param quantity Order quantity
    /// @param isBuy True for buy order
    /// @return orderId The created order ID
    function placeOrder(uint256 price, uint256 quantity, bool isBuy) 
        external 
        returns (uint256 orderId);
    
    /// @notice Cancel an order
    /// @param orderId Order to cancel
    function cancelOrder(uint256 orderId) external;
    
    /// @notice Match orders and return execution details
    /// @return matchedVolume Total matched volume
    /// @return avgPrice Average execution price
    function matchOrders() external returns (uint256 matchedVolume, uint256 avgPrice);
    
    /// @notice Get orderbook depth
    /// @return bidDepth Total bid liquidity
    /// @return askDepth Total ask liquidity
    function getDepth() external view returns (uint256 bidDepth, uint256 askDepth);

    /// @notice Get all active orders
    /// @return orders List of orders
    function getOrders() external view returns (LOBOrder[] memory orders);
}

/// @title IFeeEngine Interface
/// @notice Interface for dynamic fee calculation
interface IFeeEngine {
    /// @notice Calculate dynamic fee for a trade
    /// @param volume Trade volume
    /// @param volatility Current volatility
    /// @param longOI Long open interest
    /// @param shortOI Short open interest
    /// @return fee The dynamic fee in basis points
    function calculateFee(
        uint256 volume,
        uint256 volatility,
        uint256 longOI,
        uint256 shortOI
    ) external view returns (uint24 fee);
    
    /// @notice Get base fee
    /// @return baseFee The base fee in basis points
    function getBaseFee() external view returns (uint24 baseFee);
    
    /// @notice Update base fee (admin only)
    /// @param newBaseFee New base fee
    function setBaseFee(uint24 newBaseFee) external;
}

/// @title IOracleEngine Interface
/// @notice Interface for oracle price feeds
interface IOracleEngine {
    /// @notice Get latest oracle price
    /// @return price The oracle price
    /// @return timestamp Last update timestamp
    function getOraclePrice() external view returns (uint256 price, uint256 timestamp);
    
    /// @notice Set price feed address
    /// @param feed Chainlink price feed address
    function setPriceFeed(address feed) external;
    
    /// @notice Check if oracle is healthy
    /// @return True if oracle data is fresh and valid
    function isOracleHealthy() external view returns (bool);
}

/// @title IAdminModule Interface
/// @notice Interface for admin controls
interface IAdminModule {
    /// @notice Check if address is admin
    /// @param account Address to check
    /// @return True if admin
    function isAdmin(address account) external view returns (bool);
    
    /// @notice Grant admin role
    /// @param account Address to grant admin
    function grantAdmin(address account) external;
    
    /// @notice Revoke admin role
    /// @param account Address to revoke admin
    function revokeAdmin(address account) external;
    
    /// @notice Pause the system
    function pause() external;
    
    /// @notice Unpause the system
    function unpause() external;
    
    /// @notice Check if system is paused
    /// @return True if paused
    function isPaused() external view returns (bool);
}
