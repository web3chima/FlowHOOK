import clsx from 'clsx';
import { useCurveMode, CurveMode } from '../../hooks/useCurveMode';
import type { CurveModeType } from '../../hooks/useCurveMode';
import { Loader2, BookOpen, Layers, Activity, Radio } from 'lucide-react';

// Import dashboard variants
import { OrderbookView } from '../orderbook/OrderbookView';
import { PositionsTabs } from '../positions/PositionsTabs';
import { VAMMDashboard } from '../vamm/VAMMDashboard';

interface DashboardRouterProps {
    priceDisplay: React.ReactNode;
    priceChart: React.ReactNode;
    orderForm: React.ReactNode;
    balanceBreakdown: React.ReactNode;
    marketOverview: React.ReactNode;
    transactionStatus: React.ReactNode;
}

export const DashboardRouter = ({
    priceDisplay,
    priceChart,
    orderForm,
    balanceBreakdown,
    marketOverview,
    transactionStatus,
}: DashboardRouterProps) => {
    const { mode, modeLabel, modeDescription, isLoading, showOrderbook, showPool, showOraclePrice } = useCurveMode();

    if (isLoading) {
        return (
            <div className="flex items-center justify-center h-full bg-black">
                <div className="flex flex-col items-center gap-3">
                    <Loader2 className="w-8 h-8 text-emerald-500 animate-spin" />
                    <p className="text-zinc-500 text-sm">Detecting curve mode...</p>
                </div>
            </div>
        );
    }

    return (
        <div className="flex flex-col h-full bg-black">
            {/* Mode Indicator Banner */}
            <div className="flex items-center justify-between px-3 py-2 bg-zinc-900/50 border-b border-zinc-800">
                <div className="flex items-center gap-2">
                    <ModeIcon mode={mode} />
                    <span className="text-xs font-bold text-zinc-200 uppercase">{modeLabel}</span>
                </div>
                <span className="text-[10px] text-zinc-500">{modeDescription}</span>
            </div>

            {/* Dynamic Content based on Mode */}
            <div className="flex-1 flex flex-col overflow-hidden">
                {/* Top: Price Display & Market Overview */}
                <div className="flex items-center gap-4 px-3 py-2 bg-black/80 border-b border-zinc-800/50">
                    {priceDisplay}
                    {marketOverview}
                </div>

                {/* Main Content Area */}
                <div className="flex-1 flex min-h-0">
                    {/* Left: Charts + Positions */}
                    <div className="flex-1 flex flex-col min-w-0 border-r border-zinc-800">
                        {/* Chart */}
                        <div className="flex-[3] relative overflow-hidden">
                            {priceChart}
                        </div>

                        {/* Positions */}
                        <div className="flex-[2] overflow-hidden">
                            <PositionsTabs />
                        </div>
                    </div>

                    {/* Middle: Orderbook (LOB/HYBRID) or Pool Depth (VAMM) */}
                    {(showOrderbook || showPool) && (
                        <div className="w-80 shrink-0 border-r border-zinc-800 bg-black flex flex-col overflow-hidden">
                            {showOrderbook && (
                                <div className="flex-1 overflow-hidden">
                                    <div className="p-2 border-b border-zinc-800">
                                        <h3 className="text-xs font-mono text-zinc-500 uppercase">
                                            {mode === CurveMode.HYBRID ? 'Orderbook + Pool' : 'Orderbook'}
                                        </h3>
                                    </div>
                                    <OrderbookView />
                                </div>
                            )}
                            {showPool && !showOrderbook && (
                                <div className="flex-1 overflow-auto">
                                    <VAMMDashboard className="h-full" />
                                </div>
                            )}
                        </div>
                    )}

                    {/* Oracle Mode: Price Feed Panel */}
                    {showOraclePrice && (
                        <div className="w-80 shrink-0 border-r border-zinc-800 bg-black flex flex-col">
                            <div className="p-2 border-b border-zinc-800">
                                <h3 className="text-xs font-mono text-zinc-500 uppercase">Oracle Price Feed</h3>
                            </div>
                            <div className="flex-1 flex items-center justify-center">
                                <div className="text-center p-4">
                                    <Radio className="w-8 h-8 text-emerald-500 mx-auto mb-2" />
                                    <p className="text-zinc-300 text-lg font-mono">$3,245.67</p>
                                    <p className="text-zinc-500 text-xs">Chainlink ETH/USD</p>
                                    <p className="text-emerald-500 text-xs mt-1">Instant Execution</p>
                                </div>
                            </div>
                        </div>
                    )}

                    {/* Right: Trade Form */}
                    <div className="w-96 shrink-0 bg-black flex flex-col overflow-hidden">
                        <div className="p-3 flex flex-col gap-4 overflow-y-auto">
                            {balanceBreakdown}
                            {orderForm}
                            {transactionStatus}
                        </div>
                    </div>
                </div>
            </div>
        </div>
    );
};

// Mode Icon component
function ModeIcon({ mode }: { mode: CurveModeType }) {
    const iconClass = "w-4 h-4";
    switch (mode) {
        case CurveMode.LOB:
            return <BookOpen className={clsx(iconClass, "text-blue-400")} />;
        case CurveMode.HYBRID:
            return <Layers className={clsx(iconClass, "text-emerald-400")} />;
        case CurveMode.VAMM:
            return <Activity className={clsx(iconClass, "text-purple-400")} />;
        case CurveMode.ORACLE:
            return <Radio className={clsx(iconClass, "text-orange-400")} />;
        default:
            return null;
    }
}
