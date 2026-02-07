import { useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { useCurveMode, CurveMode, type CurveModeType } from '../../hooks/useCurveMode';
import { useAdmin } from '../../hooks/useAdmin';
import { getContractAddress } from '../../lib/contracts';
import { FLOW_HOOK_ROUTER_ABI } from '../../abi/contracts';
import { useChainId } from 'wagmi';
import { Loader2, Settings, AlertTriangle, CheckCircle2 } from 'lucide-react';
import clsx from 'clsx';
import { useEffect } from 'react';

export const ModelSelector = () => {
    const { mode, isLoading: isModeLoading, refetch } = useCurveMode();
    const { isAdmin, isLoading: isAdminLoading } = useAdmin();
    const chainId = useChainId();
    const contractAddress = getContractAddress(chainId);

    const { writeContract, data: hash, isPending, error } = useWriteContract();

    const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
        hash,
    });

    useEffect(() => {
        if (isSuccess) {
            refetch();
        }
    }, [isSuccess, refetch]);

    const handleSetMode = (newMode: CurveModeType) => {
        if (!isAdmin || !contractAddress) return;

        writeContract({
            address: contractAddress as `0x${string}`,
            abi: FLOW_HOOK_ROUTER_ABI,
            functionName: 'setCurveMode',
            args: [newMode]
        });
    };

    if (isAdminLoading || isModeLoading) {
        return <div className="p-4"><Loader2 className="animate-spin text-zinc-500" /></div>;
    }

    if (!isAdmin) {
        return (
            <div className="p-4 bg-zinc-900/50 rounded-lg border border-zinc-800">
                <h3 className="text-zinc-400 font-bold mb-2 flex items-center gap-2">
                    <Settings className="w-4 h-4" />
                    Market Model
                </h3>
                <div className="text-sm text-zinc-500">
                    Current Mode: <span className="text-zinc-200 font-mono">{getModeName(mode)}</span>
                </div>
            </div>
        );
    }

    return (
        <div className="p-6 bg-zinc-900 rounded-xl border border-zinc-800 col-span-1 lg:col-span-3">
            <div className="flex items-center justify-between mb-4">
                <h3 className="text-zinc-200 font-bold flex items-center gap-2">
                    <Settings className="w-5 h-5 text-purple-500" />
                    Model Configuration
                </h3>
                {isPending && <span className="text-xs text-purple-400 animate-pulse">Confirming...</span>}
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
                {[CurveMode.LOB, CurveMode.HYBRID, CurveMode.VAMM, CurveMode.ORACLE].map((m) => (
                    <button
                        key={m}
                        onClick={() => handleSetMode(m as CurveModeType)}
                        disabled={isPending || isConfirming || mode === m}
                        className={clsx(
                            "p-3 rounded-lg border text-left transition-all relative overflow-hidden",
                            mode === m
                                ? "bg-purple-900/20 border-purple-500/50 text-purple-300 ring-1 ring-purple-500/30"
                                : "bg-zinc-950 border-zinc-800 text-zinc-400 hover:border-zinc-700 hover:bg-zinc-900",
                            (isPending || isConfirming) && "opacity-50 cursor-not-allowed"
                        )}
                    >
                        {mode === m && (
                            <div className="absolute top-2 right-2 text-purple-500">
                                <CheckCircle2 className="w-4 h-4" />
                            </div>
                        )}
                        <div className="text-xs font-bold uppercase mb-1">{getModeName(m as CurveModeType)}</div>
                        <div className="text-[10px] opacity-70 leading-tight">
                            {getModeDescription(m as CurveModeType)}
                        </div>
                    </button>
                ))}
            </div>

            {error && (
                <div className="mt-4 p-3 bg-red-900/10 border border-red-500/20 rounded text-xs text-red-400 flex items-center gap-2">
                    <AlertTriangle className="w-4 h-4" />
                    {error.message.split('\n')[0]}
                </div>
            )}

            {isSuccess && (
                <div className="mt-4 p-3 bg-emerald-900/10 border border-emerald-500/20 rounded text-xs text-emerald-400 flex items-center gap-2">
                    <CheckCircle2 className="w-4 h-4" />
                    Successfully updated market model!
                </div>
            )}
        </div>
    );
};

function getModeName(mode: CurveModeType): string {
    switch (mode) {
        case CurveMode.LOB: return 'Limit Order Book';
        case CurveMode.HYBRID: return 'Hybrid (LOB + AMM)';
        case CurveMode.VAMM: return 'Virtual AMM';
        case CurveMode.ORACLE: return 'Oracle Pricing';
        default: return 'Unknown';
    }
}

function getModeDescription(mode: CurveModeType): string {
    switch (mode) {
        case CurveMode.LOB: return 'Traditional matching engine. Best for high liquidity pairs.';
        case CurveMode.HYBRID: return 'Orderbook overlay on AMM curve. Deep liquidity fallback.';
        case CurveMode.VAMM: return 'Infinite liquidity with price impact. P = K / Q². Best for perps.';
        case CurveMode.ORACLE: return 'Zero price impact. Oracle feed settlement. Best for synthetics.';
        default: return '';
    }
}
