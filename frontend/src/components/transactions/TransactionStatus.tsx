import { useTransactionStatus } from '../../hooks/useTransactions';
import { useOrderbookStore } from '../../stores/orderbookStore';
import { Loader2, XCircle, CheckCircle2 } from 'lucide-react';
import { useChainId, useConfig } from 'wagmi';
import { getChainId } from '@wagmi/core';

export const TransactionStatus = () => {
    const chainId = useChainId();
    const config = useConfig();
    const lastTxHash = useOrderbookStore(state => state.lastTxHash as `0x${string}` | null);
    const { isLoading, isError, isSuccess } = useTransactionStatus(lastTxHash || undefined);
    const hash = lastTxHash;

    const networkName = config.chains.find(c => c.id === chainId)?.name || 'Unknown Network';

    const downloadReceipt = () => {
        if (!hash) return;
        const receipt = {
            hash,
            timestamp: new Date().toISOString(),
            status: isSuccess ? 'Success' : 'Failed',
            network: networkName
        };
        const blob = new Blob([JSON.stringify(receipt, null, 2)], { type: 'application/json' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `tx-${hash.slice(0, 8)}.json`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
    };

    if (isLoading) {
        return (
            <div className="fixed bottom-4 right-4 bg-slate-900 border border-blue-500/50 p-4 rounded-xl shadow-2xl flex items-center gap-3 animate-slide-up z-50">
                <Loader2 className="w-5 h-5 text-blue-500 animate-spin" />
                <div>
                    <div className="font-bold text-slate-200">Transaction Pending</div>
                    <div className="text-xs text-slate-400">Waiting for confirmation...</div>
                </div>
            </div>
        );
    }

    if (isError) {
        return (
            <div className="fixed bottom-4 right-4 bg-slate-900 border border-red-500/50 p-4 rounded-xl shadow-2xl flex items-center gap-3 animate-slide-up z-50">
                <XCircle className="w-5 h-5 text-red-500" />
                <div>
                    <div className="font-bold text-slate-200">Transaction Failed</div>
                    {/* Simplified error parsing */}
                    <div className="text-xs text-red-400 max-w-[200px] truncate">
                        Request rejected or execution reverted.
                    </div>
                </div>
            </div>
        );
    }

    if (isSuccess) {
        return (
            <div className="fixed bottom-4 right-4 bg-slate-900 border border-emerald-500/50 p-4 rounded-xl shadow-2xl animate-slide-up z-50">
                <div className="flex items-center gap-3 mb-2">
                    <CheckCircle2 className="w-5 h-5 text-emerald-500" />
                    <div>
                        <div className="font-bold text-slate-200">Transaction Confirmed</div>
                        <div className="text-xs text-slate-400">View on Explorer</div>
                    </div>
                </div>
                <button
                    onClick={downloadReceipt}
                    className="text-xs text-blue-400 hover:text-blue-300 w-full text-right"
                >
                    Download Receipt
                </button>
            </div>
        );
    }

    return null;
};
