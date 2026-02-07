import { useState, useMemo } from 'react';
import clsx from 'clsx';
import { useVAMMCurve, useVAMMTradeSimulation } from '../../hooks/useVAMMCurve';
import { TrendingUp, TrendingDown, Activity, Zap, AlertTriangle, ChevronRight, Maximize2, Minimize2 } from 'lucide-react';

interface VAMMDashboardProps {
    className?: string;
}

/**
 * VAMM Dashboard Component
 * Displays custom curve state: P = K × Q^(-2)
 * Shows pool constant (K), vBTC quantity (Q), price, and sensitivity
 */
export function VAMMDashboard({ className }: VAMMDashboardProps) {
    const [isExpanded, setIsExpanded] = useState(false);
    const {
        curveState,
        openInterest,
        formattedPrice,
        formattedQuantity,
        priceSensitivityLevel,
        volatilityTrend,
        isLoading,
        error,
    } = useVAMMCurve();

    // Sensitivity color based on level
    const sensitivityColor = useMemo(() => {
        switch (priceSensitivityLevel) {
            case 'low': return 'text-green-400';
            case 'medium': return 'text-yellow-400';
            case 'high': return 'text-orange-400';
            case 'extreme': return 'text-red-400';
            default: return 'text-gray-400';
        }
    }, [priceSensitivityLevel]);

    // Volatility trend icon and color
    const trendConfig = useMemo(() => {
        switch (volatilityTrend) {
            case 'increasing':
                return { icon: TrendingUp, color: 'text-red-400', label: 'Increasing' };
            case 'decreasing':
                return { icon: TrendingDown, color: 'text-green-400', label: 'Decreasing' };
            default:
                return { icon: Activity, color: 'text-gray-400', label: 'Neutral' };
        }
    }, [volatilityTrend]);

    const containerClasses = isExpanded
        ? "fixed inset-0 z-50 bg-black/95 p-8 overflow-y-auto flex flex-col gap-6"
        : clsx('bg-gray-900 rounded-lg p-6 space-y-6 relative transition-all duration-300', className);

    if (isLoading) {
        return (
            <div className={clsx('bg-gray-900 rounded-lg p-6', className)}>
                <div className="animate-pulse space-y-4">
                    <div className="h-6 bg-gray-700 rounded w-1/3"></div>
                    <div className="grid grid-cols-2 gap-4">
                        <div className="h-24 bg-gray-700 rounded"></div>
                        <div className="h-24 bg-gray-700 rounded"></div>
                    </div>
                </div>
            </div>
        );
    }

    if (error) {
        return (
            <div className={clsx('bg-gray-900 rounded-lg p-6', className)}>
                <div className="flex items-center gap-2 text-red-400">
                    <AlertTriangle size={20} />
                    <span>Failed to load VAMM curve state</span>
                </div>
            </div>
        );
    }

    return (
        <div className={containerClasses}>
            {/* Header */}
            <div className="flex items-center justify-between shrink-0">
                <h2 className="text-xl font-bold text-white flex items-center gap-2">
                    <Zap className="text-purple-400" size={24} />
                    VAMM Curve State
                </h2>
                <div className="flex items-center gap-4">
                    <span className="text-xs text-gray-500 font-mono hidden sm:inline">
                        P = K × Q<sup>-2</sup>
                    </span>
                    <button
                        onClick={() => setIsExpanded(!isExpanded)}
                        className="p-1.5 hover:bg-gray-800 rounded-md text-gray-400 hover:text-white transition-colors"
                        title={isExpanded ? "Collapse" : "Expand"}
                    >
                        {isExpanded ? <Minimize2 size={18} /> : <Maximize2 size={18} />}
                    </button>
                </div>
            </div>

            {/* Main Metrics Grid */}
            <div className={clsx("grid gap-4", isExpanded ? "grid-cols-2 lg:grid-cols-4 select-text" : "grid-cols-2")}>
                {/* Current Price */}
                <MetricCard
                    label="Index Price"
                    value={`$${formattedPrice}`}
                    subtext="Market Price (P = K / Q²)"
                    icon={<Activity className="text-blue-400" size={18} />}
                />

                {/* Pool Quantity */}
                <MetricCard
                    label="Liquidity Depth (Q)"
                    value={formattedQuantity}
                    subtext="Available vBTC in Pool"
                    icon={<ChevronRight className="text-cyan-400" size={18} />}
                />

                {/* Price Sensitivity */}
                <MetricCard
                    label="Price Impact Risk"
                    value={priceSensitivityLevel.toUpperCase()}
                    subtext={`Sensitivity: ${priceSensitivityLevel}`}
                    icon={<Zap className={sensitivityColor} size={18} />}
                    valueClassName={sensitivityColor}
                />

                {/* Volatility Trend */}
                <MetricCard
                    label="Volatility Trend"
                    value={trendConfig.label}
                    subtext={`Market Sentiment: ${trendConfig.label}`}
                    icon={<trendConfig.icon className={trendConfig.color} size={18} />}
                    valueClassName={trendConfig.color}
                />
            </div>

            {/* Open Interest Section */}
            {openInterest && (
                <div className="border-t border-gray-800 pt-4">
                    <h3 className="text-sm font-medium text-gray-400 mb-3">Open Interest Breakdown</h3>
                    <div className="grid grid-cols-3 gap-4">
                        <OICard
                            label="Long OI"
                            value={openInterest.longOI}
                            color="text-green-400"
                            coefficient={`+${(Number(curveState?.priceSensitivity || 0n) / 1e18).toExponential(3)}`}
                            subtext="Impact/Unit"
                        />
                        <OICard
                            label="Short OI"
                            value={openInterest.shortOI}
                            color="text-red-400"
                            coefficient={`-${(Number(curveState?.priceSensitivity || 0n) / 1e18).toExponential(3)}`}
                            subtext="Impact/Unit"
                        />
                        <OICard
                            label="Net OI"
                            value={openInterest.netOI}
                            color={Number(openInterest.netOI) >= 0 ? 'text-green-400' : 'text-red-400'}
                            isNet
                        />
                    </div>
                </div>
            )}

            {/* Pool Constant */}
            {curveState && (
                <div className="border-t border-gray-800 pt-4">
                    <div className="flex items-center justify-between text-sm">
                        <span className="text-gray-400">Pool Constant (K)</span>
                        <span className="font-mono text-gray-300">
                            {(Number(curveState.poolConstant) / 1e36).toExponential(4)}
                        </span>
                    </div>
                </div>
            )}

            {/* Causation Flow Explanation */}
            <div className="bg-gray-800/50 rounded-lg p-4 text-xs text-gray-400">
                <div className="flex items-center gap-2 mb-2">
                    <Activity size={14} className="text-purple-400" />
                    <span className="font-medium text-gray-300">Causation Flow</span>
                </div>
                <div className="space-y-1">
                    <p>• <span className="text-green-400">Long opened</span> → Q ↓ → Price sensitivity ↑ → Volatility ↑</p>
                    <p>• <span className="text-red-400">Short opened</span> → Q ↑ → Price sensitivity ↓ → Volatility ↓</p>
                </div>
            </div>
        </div>
    );
}

// ============ Sub-components ============

interface MetricCardProps {
    label: string;
    value: string;
    subtext: string;
    icon: React.ReactNode;
    valueClassName?: string;
}

// Number formatter for human readability (e.g. 1.5B, 100M)
const formatCompactNumber = (value: string | number | bigint) => {
    const num = Number(value);
    if (isNaN(num)) return '-';
    if (num === 0) return '0';

    // Tiny numbers
    if (Math.abs(num) < 0.0001) return '< 0.0001';
    if (Math.abs(num) < 0.01) return num.toFixed(6);

    // Standard formatting
    return new Intl.NumberFormat('en-US', {
        notation: "compact",
        maximumFractionDigits: 2
    }).format(num);
};

function MetricCard({ label, value, subtext, icon, valueClassName }: MetricCardProps) {
    // Check if value is a "formatted" number (string with commas etc) or raw
    // If it looks like a number, try to compact it if it's too long
    let displayValue = value;
    if (typeof value === 'string' && value.length > 10 && !value.includes('e')) {
        // Try to parse and compact if it's a clean number string
        const clean = value.replace(/[$,]/g, '');
        if (!isNaN(Number(clean))) {
            displayValue = (value.includes('$') ? '$' : '') + formatCompactNumber(clean);
        }
    }

    return (
        <div className="bg-gray-800 rounded-lg p-4 min-w-0 overflow-hidden flex flex-col justify-between h-full border border-gray-700/50 hover:border-gray-600 transition-colors">
            <div>
                <div className="flex items-center gap-2 mb-2">
                    {icon}
                    <span className="text-xs text-gray-400 whitespace-nowrap font-medium tracking-wide">{label}</span>
                </div>
                <div className={clsx('text-2xl font-bold truncate tracking-tight', valueClassName || 'text-white')} title={value}>
                    {displayValue}
                </div>
            </div>
            <div className="text-[10px] text-gray-500 font-mono mt-3 pt-2 border-t border-gray-700/50 break-words leading-tight">{subtext}</div>
        </div>
    );
}

interface OICardProps {
    label: string;
    value: bigint;
    color: string;
    coefficient?: string;
    subtext?: string;
    isNet?: boolean;
}

function OICard({ label, value, color, coefficient, subtext, isNet }: OICardProps) {
    const formattedValue = useMemo(() => {
        const num = Number(value) / 1e18; // OI is usually readable
        if (isNet) {
            const val = num >= 0 ? `+${formatCompactNumber(num)}` : formatCompactNumber(num);
            return val;
        }
        return formatCompactNumber(num);
    }, [value, isNet]);

    // Format coefficient to be readable (e.g. "High Impact") instead of scientific notation if possible
    // Or just clean up the scientific notation
    const formattedCoeff = useMemo(() => {
        if (!coefficient) return null;
        // If it's scientific and huge/tiny, keep it but maybe simplify?
        // Actually, user wants "understandable".
        // Let's just show the raw value in a readable way or hide if too complex.
        // For now, let's just make it smaller font.
        return coefficient;
    }, [coefficient]);

    return (
        <div className="bg-gray-800/50 rounded-lg p-3 min-w-0 border border-gray-700/30">
            <div className="text-xs text-gray-400 mb-1 font-medium">{label}</div>
            <div className={clsx('text-xl font-bold truncate', color)} title={formattedValue}>{formattedValue}</div>
            {formattedCoeff && (
                <div className="flex flex-col mt-2 pt-2 border-t border-gray-700/30 gap-0.5">
                    <span className="text-[10px] text-gray-500 font-mono truncate opacity-70" title={formattedCoeff}>
                        Impact: {formattedCoeff}
                    </span>
                </div>
            )}
        </div>
    );
}

// ============ Trade Simulation Preview ============

interface TradeSimulationPreviewProps {
    size: bigint;
    isLong: boolean;
}

export function TradeSimulationPreview({ size, isLong }: TradeSimulationPreviewProps) {
    const { simulation, isLoading } = useVAMMTradeSimulation(size, isLong);

    if (isLoading) {
        return <div className="text-gray-400 text-sm">Simulating...</div>;
    }

    if (!simulation) {
        return null;
    }

    const formattedPrice = (Number(simulation.expectedPrice) / 1e18).toFixed(2);
    const impactPercent = (Number(simulation.expectedImpact) / 1e16).toFixed(2);

    return (
        <div className="bg-gray-800 rounded-lg p-3 text-sm">
            <div className="flex justify-between mb-1">
                <span className="text-gray-400">Expected Price</span>
                <span className="text-white font-mono">${formattedPrice}</span>
            </div>
            <div className="flex justify-between">
                <span className="text-gray-400">Price Impact</span>
                <span className={isLong ? 'text-green-400' : 'text-red-400'}>
                    {isLong ? '+' : '-'}{impactPercent}%
                </span>
            </div>
        </div>
    );
}

export default VAMMDashboard;
