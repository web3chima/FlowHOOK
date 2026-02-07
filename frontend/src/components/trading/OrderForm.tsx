import { useState } from 'react';
import { useAccount, useBalance } from 'wagmi';
import { useOrders } from '../../hooks/useOrders';
import clsx from 'clsx';
import { Loader2 } from 'lucide-react';
import { QuickPriceSelector } from './QuickPriceSelector';
import { GasEstimator } from '../transactions/GasEstimator';
import { useOrderbookStore } from '../../stores/orderbookStore';
import { formatEther } from 'viem';

export const OrderForm = () => {
    const { isConnected, address } = useAccount();
    const { data: ethBalance } = useBalance({ address });
    const { placeOrder, isPending, isConfirmed, error, hash } = useOrders();
    const setLastTxHash = useOrderbookStore(state => state.setLastTxHash);

    // Sync hash to global store for TransactionStatus
    if (hash) {
        setLastTxHash(hash);
    }

    const [isBuy, setIsBuy] = useState(true);
    const [price, setPrice] = useState('');
    const [quantity, setQuantity] = useState('');

    // Compute available balance
    const availableBalance = ethBalance ? parseFloat(formatEther(ethBalance.value)).toFixed(4) : '0.00';

    const handleSubmit = (e: React.FormEvent) => {
        e.preventDefault();
        if (!price || !quantity) return;
        placeOrder(isBuy, price, quantity);
    };

    const isFormValid = price && quantity && parseFloat(price) > 0 && parseFloat(quantity) > 0;

    return (
        <div className="flex flex-col h-full bg-black text-xs font-mono">
            {/* Header / Tabs - Pro Segmented Control */}
            <div className="flex p-1 bg-zinc-900 rounded-lg mb-6 border border-zinc-800">
                <button
                    onClick={() => setIsBuy(true)}
                    className={clsx(
                        "flex-1 py-2 text-xs font-bold uppercase tracking-wider transition-all rounded-md shadow-sm",
                        isBuy
                            ? "bg-emerald-500 text-black shadow-emerald-500/20"
                            : "text-zinc-500 hover:text-zinc-300 hover:bg-zinc-800/50"
                    )}
                >
                    Buy
                </button>
                <div className="w-px bg-zinc-800 my-1 mx-1" />
                <button
                    onClick={() => setIsBuy(false)}
                    className={clsx(
                        "flex-1 py-2 text-xs font-bold uppercase tracking-wider transition-all rounded-md shadow-sm",
                        !isBuy
                            ? "bg-red-500 text-black shadow-red-500/20"
                            : "text-zinc-500 hover:text-zinc-300 hover:bg-zinc-800/50"
                    )}
                >
                    Sell
                </button>
            </div>

            <form onSubmit={handleSubmit} className="space-y-5 px-1 flex-1 flex flex-col">
                <div>
                    <label className="flex justify-between text-zinc-500 mb-1.5 uppercase tracking-wider text-[10px] font-bold">
                        <span>Price (ETH)</span>
                        <span className="text-zinc-600 cursor-pointer hover:text-zinc-400">Market</span>
                    </label>
                    <div className="relative group">
                        <input
                            type="number"
                            value={price}
                            onChange={(e) => setPrice(e.target.value)}
                            placeholder="0.00"
                            step="0.0001"
                            min="0"
                            className="w-full bg-black border border-zinc-800 rounded-lg py-3 px-4 text-white placeholder-zinc-800 focus:outline-none focus:border-zinc-600 focus:ring-1 focus:ring-zinc-700 transition-all font-mono text-sm group-hover:border-zinc-700"
                        />
                        <span className="absolute right-4 top-3 text-zinc-600 text-xs font-mono">ETH</span>
                    </div>
                </div>

                <div>
                    <label className="flex justify-between text-zinc-500 mb-1.5 uppercase tracking-wider text-[10px] font-bold">
                        <span>Amount</span>
                        <span className="text-zinc-600">Avail: {availableBalance} ETH</span>
                    </label>
                    <div className="relative group">
                        <input
                            type="number"
                            value={quantity}
                            onChange={(e) => setQuantity(e.target.value)}
                            placeholder="0.00"
                            step="0.0001"
                            min="0"
                            className="w-full bg-black border border-zinc-800 rounded-lg py-3 px-4 text-white placeholder-zinc-800 focus:outline-none focus:border-zinc-600 focus:ring-1 focus:ring-zinc-700 transition-all font-mono text-sm group-hover:border-zinc-700"
                            aria-label="Amount"
                        />
                        <span className="absolute right-4 top-3 text-zinc-600 text-xs font-mono">WBTC</span>
                    </div>
                </div>

                {/* Total Cost Display */}
                <div className="bg-zinc-900/50 rounded-lg p-3 border border-zinc-800 flex justify-between items-center">
                    <span className="text-zinc-500 text-[10px] uppercase font-bold tracking-wider">Est. Total</span>
                    <span className="text-white font-mono text-sm">
                        {price && quantity ? (parseFloat(price) * parseFloat(quantity)).toFixed(6) : '0.000000'} ETH
                    </span>
                </div>

                <div className="py-2">
                    <QuickPriceSelector
                        currentPrice={useOrderbookStore.getState().midPrice ? formatEther(useOrderbookStore.getState().midPrice) : '0'}
                        onSelectPrice={setPrice}
                    />
                </div>

                <div className="pt-4 mt-auto">
                    {!isConnected ? (
                        <button
                            type="button"
                            disabled
                            className="w-full py-3.5 bg-zinc-900 border border-zinc-800 text-zinc-500 font-bold rounded-lg cursor-not-allowed uppercase text-xs tracking-widest hover:bg-zinc-800 transition-colors"
                            aria-label="Connect Wallet"
                        >
                            Connect Wallet
                        </button>
                    ) : (
                        <button
                            type="submit"
                            disabled={!isFormValid || isPending}
                            className={clsx(
                                "w-full py-3.5 font-bold rounded-lg transition-all flex items-center justify-center uppercase text-sm tracking-widest shadow-lg transform active:scale-[0.99]",
                                !isFormValid
                                    ? "bg-zinc-800 border border-zinc-700 text-zinc-500 cursor-not-allowed"
                                    : isBuy
                                        ? "bg-gradient-to-r from-emerald-500 to-emerald-600 text-black border border-emerald-400 hover:from-emerald-400 hover:to-emerald-500 shadow-emerald-500/20"
                                        : "bg-gradient-to-r from-red-500 to-red-600 text-white border border-red-500 hover:from-red-400 hover:to-red-500 shadow-red-500/20"
                            )}
                            aria-label={isBuy ? 'Place Buy Order' : 'Place Sell Order'}
                        >
                            {isPending ? (
                                <>
                                    <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                                    {isConfirmed ? 'Confirmed' : 'Confirming'}
                                </>
                            ) : (
                                <>
                                    {isBuy ? 'Buy / Long' : 'Sell / Short'}
                                </>
                            )}
                        </button>
                    )}
                    <div className="mt-4">
                        <GasEstimator />
                    </div>
                </div>

                {error && (
                    <div className="p-2 bg-red-900/10 border border-red-900/30 text-xs text-red-500">
                        {error.message.slice(0, 100)}...
                    </div>
                )}
            </form>
        </div>
    );
};
