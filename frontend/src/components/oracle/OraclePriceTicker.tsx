import { useOraclePrice } from '../../hooks/useOraclePrice';
import { Wifi, Loader2 } from 'lucide-react';

export function OraclePriceTicker() {
    const { data: btcData, isLoading: btcLoading } = useOraclePrice('BTC');
    const { data: ethData, isLoading: ethLoading } = useOraclePrice('ETH');

    if (btcLoading || ethLoading) {
        return (
            <div className="flex items-center gap-2 px-3 py-1.5 bg-zinc-900/50 rounded-lg border border-zinc-800 animate-pulse">
                <Loader2 className="w-3 h-3 text-orange-500 animate-spin" />
                <span className="text-[10px] font-mono text-zinc-500 uppercase tracking-widest">Live Market...</span>
            </div>
        );
    }

    if (!btcData || !ethData) return null;

    return (
        <div className="flex items-center gap-3">
            {/* BTC */}
            <div className="flex items-center gap-2 px-2 py-1 bg-zinc-900/50 rounded border border-zinc-800 hover:border-orange-500/30 transition-colors group cursor-default">
                <div className="flex items-center gap-2 border-r border-zinc-800 pr-2">
                    <Wifi className="w-2.5 h-2.5 text-orange-500" />
                    <span className="text-[9px] font-bold text-zinc-500 uppercase tracking-tighter">BTC</span>
                </div>
                <span className="text-xs font-mono font-bold text-white leading-none">
                    {btcData.price}
                </span>
            </div>

            {/* ETH */}
            <div className="flex items-center gap-2 px-2 py-1 bg-zinc-900/50 rounded border border-zinc-800 hover:border-blue-500/30 transition-colors group cursor-default">
                <div className="flex items-center gap-2 border-r border-zinc-800 pr-2">
                    <Wifi className="w-2.5 h-2.5 text-blue-500" />
                    <span className="text-[9px] font-bold text-zinc-500 uppercase tracking-tighter">ETH</span>
                </div>
                <span className="text-xs font-mono font-bold text-white leading-none">
                    {ethData.price}
                </span>
            </div>
        </div>
    );
}
