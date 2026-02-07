import { useOraclePrice } from '../../hooks/useOraclePrice';
import { Loader2, Activity, Wifi, ShieldCheck, AlertTriangle } from 'lucide-react';

export function OraclePriceView() {
    const { data: priceData, isLoading, refetch } = useOraclePrice();

    if (isLoading) {
        return (
            <div className="h-full flex flex-col items-center justify-center p-8 text-center space-y-4">
                <Loader2 className="w-8 h-8 text-orange-500 animate-spin" />
                <p className="text-zinc-500 text-sm">Connecting to Chainlink Feed...</p>
            </div>
        );
    }

    if (!priceData) {
        return (
            <div className="h-full flex flex-col items-center justify-center p-8 text-center space-y-4">
                <AlertTriangle className="w-12 h-12 text-red-500" />
                <p className="text-zinc-500">Failed to load price data</p>
                <button
                    onClick={() => refetch()}
                    className="px-4 py-2 bg-zinc-800 rounded text-sm hover:bg-zinc-700"
                >
                    Retry
                </button>
            </div>
        );
    }

    return (
        <div className="h-full flex flex-col items-center justify-center p-8 text-center space-y-6">
            {/* Status Icon */}
            <div className="relative">
                <div className="absolute inset-0 bg-orange-500/20 blur-xl rounded-full animate-pulse"></div>
                <div className="relative p-4 bg-zinc-900 rounded-full border border-orange-500/30">
                    <Wifi className="w-8 h-8 text-orange-500" />
                </div>
            </div>

            {/* Header */}
            <div>
                <h3 className="text-2xl font-bold text-white flex items-center justify-center gap-2">
                    {priceData.description}
                    <span className="text-xs bg-orange-500/20 text-orange-400 px-2 py-0.5 rounded border border-orange-500/30">
                        LIVE
                    </span>
                </h3>
                <p className="text-zinc-500 text-sm mt-2 max-w-xs mx-auto">
                    Trading settles instantly at the Oracle price with zero slippage.
                </p>
            </div>

            {/* Main Price Card */}
            <div className="w-full max-w-sm bg-zinc-900/50 backdrop-blur rounded-xl border border-zinc-800 p-6 space-y-4">
                <div className="text-center">
                    <div className="text-sm text-zinc-500 uppercase tracking-widest mb-1">Oracle Price</div>
                    <div className="text-4xl font-mono text-white font-bold tracking-tight">
                        {priceData.price}
                    </div>
                    <div className="text-xs text-zinc-600 mt-2 font-mono">
                        Last Updated: {priceData.lastUpdated.toLocaleTimeString()}
                    </div>
                </div>

                <div className="grid grid-cols-2 gap-4 pt-4 border-t border-zinc-800">
                    <div className="bg-black/40 p-3 rounded-lg flex flex-col items-center">
                        <Activity className="w-4 h-4 text-emerald-500 mb-1" />
                        <span className="text-xs text-zinc-500">Source</span>
                        <span className="text-sm font-medium text-zinc-300">Chainlink</span>
                    </div>
                    <div className="bg-black/40 p-3 rounded-lg flex flex-col items-center">
                        <ShieldCheck className={`w-4 h-4 mb-1 ${priceData.confidence === 'high' ? 'text-emerald-500' :
                                priceData.confidence === 'medium' ? 'text-yellow-500' : 'text-red-500'
                            }`} />
                        <span className="text-xs text-zinc-500">Confidence</span>
                        <span className={`text-sm font-medium ${priceData.confidence === 'high' ? 'text-emerald-400' :
                                priceData.confidence === 'medium' ? 'text-yellow-400' : 'text-red-400'
                            }`}>
                            {priceData.confidence.toUpperCase()}
                        </span>
                    </div>
                </div>
            </div>

            <div className="text-[10px] text-zinc-600 font-mono">
                Decimals: {priceData.decimals} • Round ID: N/A
            </div>
        </div>
    );
}
