import { useState } from 'react';
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, ReferenceDot } from 'recharts';
import { useLiveBTCPrice } from '../../hooks/useLiveBTCPrice';
import { useTradeHistory } from '../../hooks/useTradeHistory';
import { format } from 'date-fns';
import { formatEther } from 'viem';
import { TrendingUp, TrendingDown, Activity, Maximize2, Minimize2, X } from 'lucide-react';
import clsx from 'clsx';

export const PriceChart = () => {
    const [isFullscreen, setIsFullscreen] = useState(false);
    const { candles, currentPrice, priceChange, isLoading } = useLiveBTCPrice();
    const { trades } = useTradeHistory();

    // Format candle data for chart
    const chartData = candles.map(c => ({
        ...c,
        timeLabel: format(new Date(c.time * 1000), 'HH:mm'),
        displayTime: c.time
    }));

    // Map trades to chart coordinates (find nearest candle time)
    const tradeMarkers = trades.slice(0, 10).map(trade => {
        const tradePrice = parseFloat(formatEther(trade.price));
        const tradeTime = Number(trade.timestamp);

        // Find nearest candle
        let nearestCandle = chartData[chartData.length - 1];
        for (const candle of chartData) {
            if (Math.abs(candle.displayTime - tradeTime) < Math.abs(nearestCandle.displayTime - tradeTime)) {
                nearestCandle = candle;
            }
        }

        return {
            ...trade,
            chartTime: nearestCandle?.timeLabel || '',
            chartPrice: nearestCandle?.close || tradePrice,
            displayPrice: tradePrice
        };
    });

    if (isLoading) {
        return (
            <div className="bg-black h-full flex items-center justify-center">
                <div className="text-center">
                    <Activity className="w-8 h-8 text-blue-500 animate-pulse mx-auto mb-2" />
                    <p className="text-zinc-500 text-sm">Loading market data...</p>
                </div>
            </div>
        );
    }

    if (candles.length === 0) {
        return (
            <div className="bg-black h-full flex items-center justify-center">
                <div className="text-center">
                    <p className="text-zinc-500 text-sm">No market data available</p>
                    <p className="text-zinc-600 text-xs mt-1">Check your internet connection</p>
                </div>
            </div>
        );
    }

    // Fullscreen container classes
    const containerClasses = clsx(
        "bg-black flex flex-col",
        isFullscreen
            ? "fixed inset-0 z-50"
            : "h-full"
    );

    return (
        <>
            {/* Fullscreen backdrop */}
            {isFullscreen && (
                <div
                    className="fixed inset-0 bg-black/80 z-40"
                    onClick={() => setIsFullscreen(false)}
                />
            )}

            <div className={containerClasses}>
                {/* Price Header */}
                <div className="flex items-center justify-between px-4 py-2 border-b border-zinc-800">
                    <div className="flex items-center gap-3">
                        <span className="text-zinc-400 text-xs font-bold uppercase">BTC/USD Live</span>
                        {currentPrice && (
                            <span className={clsx(
                                "text-white font-bold font-mono",
                                isFullscreen ? "text-3xl" : "text-lg"
                            )}>
                                ${currentPrice.toLocaleString('en-US', { minimumFractionDigits: 2 })}
                            </span>
                        )}
                    </div>
                    <div className="flex items-center gap-4">
                        <div className={`flex items-center gap-1 ${priceChange >= 0 ? 'text-emerald-500' : 'text-red-500'}`}>
                            {priceChange >= 0 ? <TrendingUp className="w-4 h-4" /> : <TrendingDown className="w-4 h-4" />}
                            <span className="text-sm font-bold">{priceChange >= 0 ? '+' : ''}{priceChange.toFixed(2)}%</span>
                            <span className="text-zinc-500 text-xs">24h</span>
                        </div>
                        {/* Fullscreen Toggle Button */}
                        <button
                            onClick={() => setIsFullscreen(!isFullscreen)}
                            className="p-2 rounded-lg bg-zinc-800 hover:bg-zinc-700 text-zinc-400 hover:text-white transition-colors"
                            title={isFullscreen ? "Exit fullscreen" : "Fullscreen"}
                        >
                            {isFullscreen ? <Minimize2 className="w-4 h-4" /> : <Maximize2 className="w-4 h-4" />}
                        </button>
                    </div>
                </div>

                {/* Chart */}
                <div className="flex-1 min-h-0">
                    <ResponsiveContainer width="100%" height="100%">
                        <AreaChart data={chartData}>
                            <defs>
                                <linearGradient id="colorPrice" x1="0" y1="0" x2="0" y2="1">
                                    <stop offset="5%" stopColor="#3b82f6" stopOpacity={0.3} />
                                    <stop offset="95%" stopColor="#3b82f6" stopOpacity={0} />
                                </linearGradient>
                            </defs>
                            <CartesianGrid strokeDasharray="3 3" stroke="#27272a" vertical={false} />
                            <XAxis
                                dataKey="timeLabel"
                                stroke="#52525b"
                                tick={{ fontSize: 10, fontFamily: 'monospace' }}
                                tickLine={false}
                                axisLine={false}
                                minTickGap={40}
                            />
                            <YAxis
                                domain={['dataMin - 100', 'dataMax + 100']}
                                stroke="#52525b"
                                tick={{ fontSize: 10, fontFamily: 'monospace' }}
                                tickLine={false}
                                axisLine={false}
                                tickFormatter={(val) => `$${(val / 1000).toFixed(1)}k`}
                                width={50}
                            />
                            <Tooltip
                                contentStyle={{ backgroundColor: '#09090b', borderColor: '#27272a', borderRadius: '8px' }}
                                formatter={(value: number) => [`$${value.toLocaleString()}`, 'BTC Price']}
                                labelStyle={{ color: '#71717a' }}
                            />
                            <Area
                                type="monotone"
                                dataKey="close"
                                stroke="#3b82f6"
                                fillOpacity={1}
                                fill="url(#colorPrice)"
                                strokeWidth={2}
                                isAnimationActive={false}
                            />

                            {/* Trade Markers */}
                            {tradeMarkers.map((trade, idx) => (
                                <ReferenceDot
                                    key={trade.hash}
                                    x={trade.chartTime}
                                    y={trade.chartPrice}
                                    r={6}
                                    fill={trade.isLong ? '#10b981' : '#ef4444'}
                                    stroke="#fff"
                                    strokeWidth={2}
                                />
                            ))}
                        </AreaChart>
                    </ResponsiveContainer>
                </div>

                {/* Trade Legend */}
                {trades.length > 0 && (
                    <div className="px-4 py-2 border-t border-zinc-800 flex items-center gap-4 text-xs">
                        <span className="text-zinc-500">Your Trades:</span>
                        <span className="flex items-center gap-1">
                            <span className="w-2 h-2 rounded-full bg-emerald-500"></span>
                            <span className="text-zinc-400">Long</span>
                        </span>
                        <span className="flex items-center gap-1">
                            <span className="w-2 h-2 rounded-full bg-red-500"></span>
                            <span className="text-zinc-400">Short</span>
                        </span>
                        <span className="text-zinc-600 ml-auto">{trades.length} trades on-chain</span>
                    </div>
                )}
            </div>
        </>
    );
};
