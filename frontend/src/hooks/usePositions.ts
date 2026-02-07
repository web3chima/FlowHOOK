import { useTradeHistory } from './useTradeHistory';
import { useAccount } from 'wagmi';
import { useMemo } from 'react';
import { useVAMMCurve } from './useVAMMCurve';

export interface VAMMPosition {
    orderId: bigint; // Fake ID for compatibility with UI
    isBuy: boolean;
    quantity: bigint;
    price: bigint; // Average entry price
    unrealizedPnL: bigint;
    trader: string;
}

// Final cleanup of Trade interface in useTradeHistory should serve this, 
// but we'll be defensive here.
export function usePositions() {
    const { address } = useAccount();
    const { trades, isLoading: isHistoryLoading } = useTradeHistory();
    const { curveState } = useVAMMCurve();
    const currentPrice = curveState ? BigInt(curveState.currentPrice.toString()) : 0n;

    const position = useMemo(() => {
        if (!address || !trades || trades.length === 0) return null;

        // Filter for user's trades
        const userTrades = trades.filter(t => t.trader.toLowerCase() === address.toLowerCase());
        if (userTrades.length === 0) return null;

        let netSize = 0n;      // Positive = Long, Negative = Short
        let avgEntryPrice = 0n;

        // Process trades chronologically (Oldest -> Newest)
        const chronologicalTrades = [...userTrades].reverse();

        for (const trade of chronologicalTrades) {
            const size = BigInt(trade.size.toString());
            const price = BigInt(trade.price.toString());

            if (trade.isLong) {
                if (netSize >= 0n) {
                    const totalValue = (netSize * avgEntryPrice) + (size * price);
                    netSize += size;
                    avgEntryPrice = totalValue / netSize;
                } else {
                    const remainingShort = -netSize;
                    if (size <= remainingShort) {
                        netSize += size;
                        if (netSize === 0n) avgEntryPrice = 0n;
                    } else {
                        const sizeNewLong = size - remainingShort;
                        netSize = sizeNewLong;
                        avgEntryPrice = price;
                    }
                }
            } else {
                if (netSize <= 0n) {
                    const currentAbsSize = -netSize;
                    const totalValue = (currentAbsSize * avgEntryPrice) + (size * price);
                    netSize -= size;
                    const newAbsSize = -netSize;
                    avgEntryPrice = totalValue / newAbsSize;
                } else {
                    const remainingLong = netSize;
                    if (size <= remainingLong) {
                        netSize -= size;
                        if (netSize === 0n) avgEntryPrice = 0n;
                    } else {
                        const sizeNewShort = size - remainingLong;
                        netSize = -sizeNewShort;
                        avgEntryPrice = price;
                    }
                }
            }
        }

        if (netSize === 0n) return null;

        const isLong = netSize > 0n;
        const absSize = netSize > 0n ? netSize : -netSize;

        // Calculate Unrealized PnL
        // Long PnL = (Current Price - Avg Entry) * Size
        // Short PnL = (Avg Entry - Current Price) * Size
        // Scaled by 1e18? No, prices are 1e18, size is 1e18. Result is 1e36 if multiplied directly.
        // We usually want PnL in Quote Token (USDC, 6 decimals? or 18?)
        // Let's assume Quote is 18 decimals for calculation simplicity, then scale down if needed.
        // Or simply: (PriceDiff * Size) / PRECISION

        const PRECISION = 1e18;
        let pnl = 0n;

        if (currentPrice > 0n) {
            if (isLong) {
                pnl = ((currentPrice - avgEntryPrice) * absSize) / BigInt(PRECISION);
            } else {
                pnl = ((avgEntryPrice - currentPrice) * absSize) / BigInt(PRECISION);
            }
        }

        return {
            orderId: BigInt(Date.now()), // Client-side ID for UI key
            isBuy: isLong,
            quantity: absSize,
            price: avgEntryPrice,
            unrealizedPnL: pnl,
            trader: trades[0]?.hash || ''
        } as VAMMPosition;

    }, [trades, currentPrice]);

    return {
        orders: position ? [position] : [],
        isLoading: isHistoryLoading,
        isEmpty: !position
    };
}
