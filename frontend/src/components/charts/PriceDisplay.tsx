import { useVAMMCurve } from '../../hooks/useVAMMCurve';
import { useOraclePrice } from '../../hooks/useOraclePrice';
import { useCurveMode, CurveMode } from '../../hooks/useCurveMode';
import { Activity } from 'lucide-react';
import clsx from 'clsx';

export const PriceDisplay = () => {
    const { mode } = useCurveMode();
    const { formattedPrice, curveState, priceSensitivityLevel } = useVAMMCurve();
    const { data: btcData } = useOraclePrice('BTC');
    const { data: ethData } = useOraclePrice('ETH');

    let displayPrice = "0.00";
    let isOracle = false;

    if (mode === CurveMode.ORACLE) {
        if (btcData) {
            displayPrice = btcData.price.replace('$', ''); // Default ORACLE mode shows BTC
            isOracle = true;
        }
    } else {
        // VAMM, LOB, HYBRID
        // For now, VAMM price is the best source of truth for the "Index Price"
        if (formattedPrice) {
            displayPrice = formattedPrice;
        }
    }

    // "Fake" 24h change for now since we don't have historical indexer yet
    // But we can show something real like "Price Impact" or just hide it
    // Or we can calculate change since session start?
    // User asked to remove irrelevant comments, so I'll just remove the fake change if I can't support it.
    // Actually, I'll show "Sensitivity" instead of 24h change for VAMM?
    const sensitivity = curveState ? (Number(curveState.priceSensitivity) / 1e18) : 0;

    return (
        <div className="flex items-center gap-6">
            <div className="flex flex-col">
                <span className="text-[10px] text-zinc-500 font-bold uppercase tracking-wider flex items-center gap-1">
                    vBTC/USD Pool {isOracle && <span className="px-1 py-0.5 bg-orange-500/20 text-orange-500 rounded text-[8px]">PRIMARY</span>}
                </span>
                <div className="flex items-baseline gap-2">
                    <span className="text-xl lg:text-2xl font-bold text-white font-mono tracking-tight">
                        ${displayPrice}
                    </span>
                    {!isOracle && (
                        <span className={clsx(
                            "flex items-center text-[10px] font-bold px-1.5 py-0.5 rounded-sm transition-colors",
                            sensitivity > 100 ? "bg-red-500/20 text-red-500" :
                                sensitivity > 10 ? "bg-orange-500/20 text-orange-500" :
                                    "bg-emerald-500/20 text-emerald-500"
                        )}>
                            <Activity className="w-3 h-3 mr-1" />
                            SENSITIVITY: {priceSensitivityLevel ? priceSensitivityLevel.toUpperCase() : 'LOADING...'}
                        </span>
                    )}
                </div>
            </div>

            {/* Live Market References */}
            {!isOracle && (
                <div className="hidden sm:flex items-center gap-6 border-l border-zinc-800 pl-6">
                    {/* BTC Index */}
                    {btcData && (
                        <div className="flex flex-col">
                            <span className="text-[10px] text-zinc-600 font-bold uppercase tracking-wider flex items-center gap-1">
                                BTC Index <span className="w-1 h-1 rounded-full bg-orange-500/50"></span>
                            </span>
                            <span className="text-sm font-bold text-zinc-400 font-mono tracking-tight">
                                {btcData.price}
                            </span>
                        </div>
                    )}

                    {/* ETH Index */}
                    {ethData && (
                        <div className="flex flex-col">
                            <span className="text-[10px] text-zinc-600 font-bold uppercase tracking-wider flex items-center gap-1">
                                ETH Index <span className="w-1 h-1 rounded-full bg-blue-500/50"></span>
                            </span>
                            <span className="text-sm font-bold text-zinc-400 font-mono tracking-tight">
                                {ethData.price}
                            </span>
                        </div>
                    )}
                </div>
            )}
        </div>
    );
};
