import { useAccount, useBalance } from 'wagmi';
import { formatEther } from 'viem';

export const BalanceDisplay = () => {
    const { address, isConnected } = useAccount();

    // Provide specific token address here if needed, defaults to native currency
    const { data, isError, isLoading } = useBalance({
        address,
    });

    if (!isConnected) return null;

    return (
        <div className="p-4 bg-slate-800 rounded-xl border border-slate-700 shadow-sm">
            <div className="text-sm text-slate-400 mb-1">Available Balance</div>
            <div className="text-2xl font-bold text-white flex items-baseline gap-1">
                {isLoading ? (
                    <div className="h-8 w-24 bg-slate-700 rounded animate-pulse" />
                ) : isError ? (
                    <span className="text-red-400 text-base">Error fetching balance</span>
                ) : (
                    <>
                        <span>{parseFloat(formatEther(data?.value || 0n)).toFixed(4)}</span>
                        <span className="text-sm font-normal text-slate-400">{data?.symbol}</span>
                    </>
                )}
            </div>
        </div>
    );
};
