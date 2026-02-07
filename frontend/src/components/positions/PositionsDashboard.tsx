import { usePositions } from '../../hooks/usePositions';
import { useOrders } from '../../hooks/useOrders';
import { formatEther } from 'viem';
import { Loader2, Trash2 } from 'lucide-react';
import clsx from 'clsx';

export const PositionsDashboard = () => {
    const { orders, isLoading, isEmpty } = usePositions();
    const { cancelOrder, isPending } = useOrders();

    if (isLoading) {
        return (
            <div className="p-6 bg-black flex items-center justify-center h-48">
                <Loader2 className="w-6 h-6 text-zinc-600 animate-spin" />
            </div>
        );
    }

    return (
        <div className="flex flex-col h-full bg-black">
            {/* Header hidden or minimal if managed by parent */}

            <div className="flex-1 overflow-y-auto p-0 scrollbar-none">
                {isEmpty ? (
                    <div className="flex flex-col items-center justify-center h-full text-zinc-600 text-[10px] uppercase tracking-wider py-8">
                        <p>No active orders</p>
                    </div>
                ) : (
                    <div className="divide-y divide-zinc-900">
                        {orders.map((order) => (
                            <div
                                key={order.orderId.toString()}
                                className="group flex items-center justify-between py-2 px-2 hover:bg-zinc-900/50 transition-colors"
                            >
                                <div className="flex flex-col gap-0.5">
                                    <div className="flex items-center gap-2">
                                        <span className={clsx(
                                            "text-[10px] font-bold uppercase",
                                            order.isBuy ? "text-emerald-500" : "text-red-500"
                                        )}>
                                            {order.isBuy ? 'Buy' : 'Sell'}
                                        </span>
                                        <span className="text-xs font-mono text-zinc-300">
                                            {parseFloat(formatEther(order.quantity)).toFixed(4)}
                                        </span>
                                        <span className="text-[10px] text-zinc-500">
                                            @ {parseFloat(formatEther(order.price)).toFixed(4)}
                                        </span>
                                    </div>
                                </div>

                                <button
                                    onClick={() => cancelOrder(order.orderId)}
                                    disabled={isPending}
                                    className="opacity-0 group-hover:opacity-100 p-1 text-zinc-500 hover:text-red-400 transition-all"
                                    title="Cancel Order"
                                >
                                    {isPending ? (
                                        <Loader2 className="w-3 h-3 animate-spin" />
                                    ) : (
                                        <Trash2 className="w-3 h-3" />
                                    )}
                                </button>
                            </div>
                        ))}
                    </div>
                )}
            </div>
        </div>
    );
};
