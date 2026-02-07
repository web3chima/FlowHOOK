import { Clock, ExternalLink, Filter, Globe } from 'lucide-react';
import { useTradeHistory } from '../../hooks/useTradeHistory';
import { useAccount } from 'wagmi';
import { useState } from 'react';
import { formatEther } from 'viem';
import { formatDistanceToNow } from 'date-fns';
import clsx from 'clsx';

export const OrderHistory = () => {
    const { address } = useAccount();
    const { trades, isLoading } = useTradeHistory();
    const [filterByMe, setFilterByMe] = useState(true);

    const filteredTrades = filterByMe && address
        ? trades.filter(t => t.trader.toLowerCase() === address.toLowerCase())
        : trades;

    const getExplorerLink = (hash: string) => `https://sepolia.etherscan.io/tx/${hash}`;

    if (isLoading) {
        return (
            <div className="p-4 bg-black rounded-lg border border-zinc-800 text-center text-zinc-500 text-xs">
                Loading history...
            </div>
        );
    }

    return (
        <div className="p-4 bg-black rounded-lg border border-zinc-800">
            <div className="flex items-center justify-between mb-4">
                <h3 className="text-sm font-bold text-zinc-400 flex items-center gap-2 uppercase tracking-wider">
                    <Clock className="w-4 h-4 text-zinc-500" />
                    Trade History
                </h3>

                <div className="flex gap-1 bg-zinc-900 p-1 rounded border border-zinc-800">
                    <button
                        onClick={() => setFilterByMe(true)}
                        className={clsx(
                            "flex items-center gap-1.5 px-2 py-1 rounded text-[10px] font-bold uppercase transition-all",
                            filterByMe ? "bg-emerald-500/20 text-emerald-500" : "text-zinc-500 hover:text-zinc-300"
                        )}
                    >
                        <Filter className="w-3 h-3" />
                        Mine
                    </button>
                    <button
                        onClick={() => setFilterByMe(false)}
                        className={clsx(
                            "flex items-center gap-1.5 px-2 py-1 rounded text-[10px] font-bold uppercase transition-all",
                            !filterByMe ? "bg-emerald-500/20 text-emerald-500" : "text-zinc-500 hover:text-zinc-300"
                        )}
                    >
                        <Globe className="w-3 h-3" />
                        Global
                    </button>
                </div>
            </div>

            <div className="space-y-2">
                {filteredTrades.length === 0 ? (
                    <div className="text-center py-4 text-zinc-600 text-[10px] uppercase">
                        No {filterByMe ? 'personal' : ''} trade history
                    </div>
                ) : (
                    filteredTrades.map((trade) => {
                        const size = parseFloat(formatEther(trade.size)).toFixed(4);
                        const price = parseFloat(formatEther(trade.price)).toFixed(2);
                        const timeAgo = formatDistanceToNow(Number(trade.timestamp) * 1000, { addSuffix: true });

                        return (
                            <div key={trade.hash} className="flex items-center justify-between p-3 bg-zinc-900/30 rounded border border-zinc-800/50 hover:border-zinc-700 transition-colors">
                                <div className="flex items-center gap-3">
                                    <span className={`text-xs font-bold px-2 py-1 rounded uppercase ${trade.isLong ? 'bg-emerald-500/10 text-emerald-500' : 'bg-red-500/10 text-red-500'}`}>
                                        {trade.isLong ? 'Buy' : 'Sell'}
                                    </span>
                                    <div className="flex flex-col">
                                        <span className="text-sm font-mono text-zinc-200">
                                            {size} vBTC @ ${price}
                                        </span>
                                        <span className="text-[10px] text-zinc-600 uppercase">{timeAgo}</span>
                                    </div>
                                </div>

                                <a
                                    href={getExplorerLink(trade.hash)}
                                    target="_blank"
                                    rel="noopener noreferrer"
                                    className="text-zinc-600 hover:text-zinc-400"
                                >
                                    <ExternalLink className="w-3 h-3" />
                                </a>
                            </div>
                        );
                    })
                )}
            </div>
        </div>
    );
};
