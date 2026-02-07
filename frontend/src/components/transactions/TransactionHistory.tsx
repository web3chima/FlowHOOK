import { Loader2, CheckCircle2, ExternalLink, RefreshCw } from 'lucide-react';
import { useTradeHistory, type Trade } from '../../hooks/useTradeHistory';
import { formatEther } from 'viem';
import { formatDistanceToNow } from 'date-fns';

export const TransactionHistory = () => {
    const { trades, isLoading, refetch } = useTradeHistory();

    const getExplorerLink = (hash: string) => `https://sepolia.etherscan.io/tx/${hash}`;

    if (isLoading) {
        return (
            <div className="p-6 bg-slate-900 rounded-xl border border-slate-700 flex justify-center items-center h-48">
                <Loader2 className="w-6 h-6 text-emerald-500 animate-spin" />
            </div>
        );
    }

    return (
        <div className="p-6 bg-slate-900 rounded-xl border border-slate-700">
            <div className="flex items-center justify-between mb-4">
                <h3 className="text-lg font-bold text-slate-200 flex items-center gap-2">
                    Recent Transactions
                </h3>
                <button
                    onClick={() => refetch()}
                    className="p-1 hover:bg-slate-800 rounded-full transition-colors"
                >
                    <RefreshCw className="w-4 h-4 text-slate-500" />
                </button>
            </div>

            <div className="space-y-3">
                {trades.length === 0 ? (
                    <div className="text-center py-8 text-slate-500 text-sm">
                        No transactions found
                    </div>
                ) : (
                    trades.map((tx: Trade) => {
                        const size = parseFloat(formatEther(tx.size)).toFixed(4);
                        const price = parseFloat(formatEther(tx.price)).toFixed(2);
                        const timeAgo = formatDistanceToNow(Number(tx.timestamp) * 1000, { addSuffix: true });

                        return (
                            <div key={tx.hash} className="flex items-center justify-between p-3 bg-slate-950 rounded border border-slate-800 hover:border-slate-700 transition-colors">
                                <div className="flex items-center gap-3">
                                    <CheckCircle2 className="w-5 h-5 text-emerald-500" />
                                    <div className="flex flex-col">
                                        <span className="text-sm font-medium text-slate-200">
                                            {tx.isLong ? 'Buy' : 'Sell'} {size} vBTC
                                        </span>
                                        <span className="text-xs text-slate-500">
                                            @ ${price} · {timeAgo}
                                        </span>
                                    </div>
                                </div>

                                <a
                                    href={getExplorerLink(tx.hash)}
                                    target="_blank"
                                    rel="noopener noreferrer"
                                    className="text-slate-500 hover:text-blue-400 transition-colors"
                                    title="View on Etherscan"
                                >
                                    <ExternalLink className="w-4 h-4" />
                                </a>
                            </div>
                        );
                    })
                )}
            </div>
        </div>
    );
};
