import { useChainId } from 'wagmi';
import { AlertTriangle, PauseCircle, PlayCircle, Loader2 } from 'lucide-react';
import clsx from 'clsx';
import { useState } from 'react';

/**
 * Emergency Controls Component
 * Note: Pause functionality is not yet implemented in the modular contracts.
 * This is a UI placeholder for future functionality.
 */
export const EmergencyControls = () => {
    const chainId = useChainId();

    // Currently, the modular contracts don't have pause functionality
    // This is a placeholder that can be enabled when pause is added
    const [isPaused] = useState(false);
    const [isPending] = useState(false);
    const [isConfirming] = useState(false);
    const [error] = useState<Error | null>(null);

    const handleTogglePause = () => {
        // Implement when pause functionality is added to contracts
        console.warn('Pause functionality not yet implemented in modular contracts');
    };

    return (
        <div className={clsx(
            "p-6 rounded-xl border transition-all",
            isPaused
                ? "bg-red-900/10 border-red-500/30"
                : "bg-slate-900 border-slate-700"
        )}>
            <div className="flex items-center justify-between mb-4">
                <h3 className={clsx(
                    "text-lg font-bold flex items-center gap-2",
                    isPaused ? "text-red-400" : "text-emerald-400"
                )}>
                    {isPaused ? <PauseCircle className="w-6 h-6" /> : <PlayCircle className="w-6 h-6" />}
                    System Status: {isPaused ? 'PAUSED' : 'ACTIVE'}
                </h3>
            </div>

            <p className="text-slate-400 text-sm mb-6">
                {isPaused
                    ? "Trading is currently suspended. Users cannot place or cancel orders."
                    : "System is fully operational. Administrators can pause trading in case of emergency."
                }
            </p>

            {/* Network Info */}
            <div className="mb-4 p-3 bg-slate-800/50 rounded-lg text-xs text-slate-400">
                Connected to Chain ID: {chainId || 'Not connected'}
            </div>

            {error && (
                <div className="mb-4 p-3 bg-red-500/10 border border-red-500/20 rounded-lg text-xs text-red-400">
                    {error.message}
                </div>
            )}

            <button
                onClick={handleTogglePause}
                disabled={isPending || isConfirming || true}  // Disabled until implemented
                className={clsx(
                    "w-full py-3 px-4 font-bold rounded-lg flex items-center justify-center transition-all opacity-50 cursor-not-allowed",
                    isPaused
                        ? "bg-emerald-600 text-white"
                        : "bg-red-600 text-white"
                )}
            >
                {isPending || isConfirming ? (
                    <>
                        <Loader2 className="w-5 h-5 mr-2 animate-spin" />
                        {isConfirming ? 'Confirming...' : 'Processing...'}
                    </>
                ) : (
                    <>
                        {isPaused ? 'RESUME TRADING' : 'PAUSE TRADING'}
                        <span className="ml-2 text-xs opacity-75">(Coming Soon)</span>
                    </>
                )}
            </button>

            {!isPaused && (
                <div className="mt-4 flex items-center gap-2 text-xs text-amber-500 bg-amber-900/10 p-2 rounded">
                    <AlertTriangle className="w-4 h-4" />
                    Warning: Pausing will reject all new transactions.
                </div>
            )}
        </div>
    );
};
