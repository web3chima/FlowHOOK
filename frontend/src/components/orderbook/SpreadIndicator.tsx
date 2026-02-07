import { formatEther } from 'viem';

interface SpreadIndicatorProps {
    spread: bigint;
    midPrice: bigint;
}

export const SpreadIndicator = ({ spread, midPrice }: SpreadIndicatorProps) => {
    const spreadEth = parseFloat(formatEther(spread));
    const midPriceEth = parseFloat(formatEther(midPrice));

    // Prevent division by zero
    const spreadPercentage = midPriceEth > 0
        ? ((spreadEth / midPriceEth) * 100).toFixed(3)
        : '0.000';

    return (
        <div className="flex justify-between items-center px-3 py-1.5 bg-zinc-900/20 border-y border-zinc-900 my-1">
            <div className="text-[10px] text-zinc-500 uppercase tracking-wider font-bold">Spread</div>
            <div className="flex items-center gap-2">
                <span className="text-xs font-mono text-zinc-400">
                    {spreadEth.toFixed(4)}
                </span>
                <span className="text-[10px] text-zinc-600">
                    ({spreadPercentage}%)
                </span>
            </div>
        </div>
    );
};
