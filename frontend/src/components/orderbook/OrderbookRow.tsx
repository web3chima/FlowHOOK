import clsx from 'clsx';
import { formatEther } from 'viem';
import type { OrderbookLevel } from '../../types/orderbook';

interface OrderbookRowProps {
    level: OrderbookLevel;
    type: 'bid' | 'ask';
    maxTotal: bigint; // For depth visualization background
    onClick: (price: bigint) => void;
}

export const OrderbookRow = ({ level, type, maxTotal, onClick }: OrderbookRowProps) => {
    const priceFormatted = parseFloat(formatEther(level.price)).toFixed(4);
    const sizeFormatted = parseFloat(formatEther(level.quantity)).toFixed(4);
    const totalFormatted = parseFloat(formatEther(level.total)).toFixed(4); // Use cumulative total here if pre-calculated, or just size for now if simple view

    // Calculate percentage for depth bar
    // Using simplified calculation for visual - assuming maxTotal is the max cumulative volume in the view
    const depthPercentage = maxTotal > 0n
        ? Number((level.quantity * 100n) / maxTotal)
        : 0;

    return (
        <div
            className="relative flex justify-between items-center text-xs py-1 px-4 cursor-pointer hover:bg-slate-800 transition-colors"
            onClick={() => onClick(level.price)}
        >
            {/* Depth Visualization Background */}
            <div
                className={clsx(
                    "absolute top-0 bottom-0 opacity-10 transition-all duration-300",
                    type === 'bid' ? "right-0 bg-emerald-500" : "left-0 bg-red-500"
                )}
                style={{ width: `${Math.min(depthPercentage, 100)}%` }}
            />

            <div className={clsx(
                "font-medium z-10 w-1/3 text-left",
                type === 'bid' ? "text-emerald-400" : "text-red-400"
            )}>
                {priceFormatted}
            </div>
            <div className="text-slate-300 z-10 w-1/3 text-right">
                {sizeFormatted}
            </div>
            <div className="text-slate-500 z-10 w-1/3 text-right">
                {totalFormatted} {/* Or cumulative sum if passed */}
            </div>
        </div>
    );
};
