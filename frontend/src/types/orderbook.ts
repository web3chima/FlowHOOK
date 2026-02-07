export interface Order {
    orderId: bigint;
    trader: string;
    isBuy: boolean;
    price: bigint;
    quantity: bigint;
    timestamp: bigint;
    lockedAmount: bigint;
}

export interface OrderbookLevel {
    price: bigint;
    quantity: bigint;
    orderCount: number;
    total: bigint; // Cumulative sum at this level
    orders: Order[];
}

export interface OrderbookState {
    bids: OrderbookLevel[];
    asks: OrderbookLevel[];
    spread: bigint;
    midPrice: bigint;
    lastUpdated: number;
    isLoading: boolean;
    error: string | null;
    lastTxHash?: string | null;
}
