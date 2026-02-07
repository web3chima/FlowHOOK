import { useMemo } from 'react';
import { AreaChart, Area, XAxis, YAxis, Tooltip, ResponsiveContainer } from 'recharts';
import { formatEther } from 'viem';
import { useOrderbookStore } from '../../stores/orderbookStore';

interface DepthPoint {
    price: number;
    bidDepth: number | null;
    askDepth: number | null;
}

export const DepthChart = () => {
    const { bids, asks } = useOrderbookStore();

    const data = useMemo(() => {
        const chartData: DepthPoint[] = [];

        // Process Bids (Green) - Reverse to show from lowest to highest price for the left side of chart?
        // Usually depth charts show Price on X, Cumulative Vol on Y.
        // For bids: Price High -> Low (As we move left away from mid price).
        // For asks: Price Low -> High (As we move right away from mid price).

        // We want a continuous X axis of price.
        // Bids: [Lowest Price ... Highest Price_BestBid]
        // Asks: [Lowest Price_BestAsk ... Highest Price]

        // Create cumulative volume points
        const bidsReverse = [...bids].reverse(); // Low -> High
        let cumulative = 0;

        // Bids side
        bidsReverse.forEach(bid => {
            const price = parseFloat(formatEther(bid.price));
            cumulative += parseFloat(formatEther(bid.quantity));
            chartData.push({
                price,
                bidDepth: cumulative,
                askDepth: null,
            });
        });

        // Reset for asks
        cumulative = 0;

        // Asks side
        asks.forEach(ask => {
            const price = parseFloat(formatEther(ask.price));
            cumulative += parseFloat(formatEther(ask.quantity));
            chartData.push({
                price,
                bidDepth: null,
                askDepth: cumulative,
            });
        });

        return chartData;
    }, [bids, asks]);

    if (data.length === 0) {
        return (
            <div className="flex items-center justify-center h-48 bg-black border-t border-zinc-900 text-zinc-600 text-xs">
                Not enough data for Depth Chart
            </div>
        );
    }

    return (
        <div className="h-48 w-full bg-black border-t border-zinc-900 p-0 overflow-hidden mt-0 relative">
            <div className="absolute top-2 left-2 text-[10px] font-bold text-zinc-600 uppercase tracking-widest z-10">Market Depth</div>
            <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={data} margin={{ top: 20, right: 0, left: 0, bottom: 0 }}>
                    <defs>
                        <linearGradient id="colorBid" x1="0" y1="0" x2="0" y2="1">
                            <stop offset="5%" stopColor="#10b981" stopOpacity={0.3} />
                            <stop offset="95%" stopColor="#10b981" stopOpacity={0} />
                        </linearGradient>
                        <linearGradient id="colorAsk" x1="0" y1="0" x2="0" y2="1">
                            <stop offset="5%" stopColor="#ef4444" stopOpacity={0.3} />
                            <stop offset="95%" stopColor="#ef4444" stopOpacity={0} />
                        </linearGradient>
                    </defs>
                    <XAxis
                        dataKey="price"
                        type="number"
                        domain={['auto', 'auto']}
                        tick={{ fontSize: 10, fill: '#64748b' }}
                        tickFormatter={(val: number) => val.toFixed(2)}
                    />
                    <YAxis
                        hide
                    />
                    <Tooltip
                        contentStyle={{ backgroundColor: '#09090b', borderColor: '#27272a' }}
                        itemStyle={{ fontSize: '10px', fontFamily: 'monospace' }}
                        labelStyle={{ color: '#71717a', fontSize: '10px', marginBottom: '0.25rem' }}
                        formatter={(value: number | string | Array<number | string> | undefined) => [
                            (typeof value === 'number' ? value.toFixed(4) : value),
                            'Depth'
                        ]}
                        labelFormatter={(label) => `Price: ${label}`}
                    />
                    <Area
                        type="stepAfter"
                        dataKey="bidDepth"
                        stroke="#10b981"
                        fillOpacity={1}
                        fill="url(#colorBid)"
                        strokeWidth={2}
                        isAnimationActive={false}
                    />
                    <Area
                        type="stepBefore"
                        dataKey="askDepth"
                        stroke="#ef4444"
                        fillOpacity={1}
                        fill="url(#colorAsk)"
                        strokeWidth={2}
                        isAnimationActive={false}
                    />
                </AreaChart>
            </ResponsiveContainer>
        </div>
    );
};
