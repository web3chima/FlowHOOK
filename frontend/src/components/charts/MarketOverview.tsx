import { Zap, Activity, Percent } from 'lucide-react';
import { useReadContract, useChainId } from 'wagmi';
import {
    getContractAddress,
    getFeeEngineAddress,
    ORDERBOOK_ABI,
    FEE_ENGINE_ABI,
    FLOW_HOOK_ROUTER_ABI
} from '../../lib/contracts';
import { formatEther } from 'viem';

export const MarketOverview = () => {
    const chainId = useChainId();
    const contractAddress = getContractAddress(chainId);
    const feeAddress = getFeeEngineAddress(chainId);

    // Read Base Fee from FeeEngine
    const { data: baseFeeRaw } = useReadContract({
        address: feeAddress as `0x${string}`,
        abi: FEE_ENGINE_ABI,
        functionName: 'baseFee',
        query: { enabled: !!feeAddress }
    });

    // Read Open Interest from FlowHookRouter
    const { data: oiData } = useReadContract({
        address: contractAddress as `0x${string}`,
        abi: FLOW_HOOK_ROUTER_ABI,
        functionName: 'getOpenInterest',
        query: { enabled: !!contractAddress }
    });

    // Read Current Price from Router
    const { data: currentPriceRaw } = useReadContract({
        address: contractAddress as `0x${string}`,
        abi: FLOW_HOOK_ROUTER_ABI,
        functionName: 'getCurrentPrice',
        query: { enabled: !!contractAddress }
    });

    // Parse values with fallbacks
    // baseFee is in basis points (e.g., 3000 = 0.3%)
    const baseFee = baseFeeRaw ? Number(baseFeeRaw) / 10000 : 0.003;
    const currentFee = baseFee * 100; // Convert to percentage

    // Parse OI data
    const oiArray = oiData as readonly [bigint, bigint, bigint] | undefined;
    const totalLong = oiArray ? parseFloat(formatEther(oiArray[0])) : 0;
    const totalShort = oiArray ? parseFloat(formatEther(oiArray[1])) : 0;
    const totalOI = totalLong + totalShort;
    const oiRatio = totalOI > 0 ? totalLong / totalOI : 0.5;

    // Current price
    const currentPrice = currentPriceRaw
        ? parseFloat(formatEther(currentPriceRaw as bigint))
        : 0;

    return (
        <div className="flex items-center gap-3 text-[10px] uppercase font-bold tracking-wider text-zinc-500 select-none pointer-events-auto">
            {/* Price */}
            <div className="flex items-center gap-1.5 px-2 py-1 bg-zinc-900/50 rounded border border-zinc-800/50 hover:bg-zinc-800 transition-colors cursor-help group relative">
                <Zap className="w-3 h-3 text-yellow-500" />
                <span>Price</span>
                <span className="text-zinc-300 font-mono">${currentPrice.toLocaleString(undefined, { maximumFractionDigits: 2 })}</span>
            </div>

            {/* Fee */}
            <div className="flex items-center gap-1.5 px-2 py-1 bg-zinc-900/50 rounded border border-zinc-800/50 hover:bg-zinc-800 transition-colors cursor-help group relative">
                <Percent className="w-3 h-3 text-blue-500" />
                <span>Fee</span>
                <span className="text-zinc-300 font-mono">{currentFee.toFixed(2)}%</span>

                {/* Tooltip */}
                <div className="absolute top-full mt-2 left-0 w-48 p-2 bg-black border border-zinc-800 rounded opacity-0 group-hover:opacity-100 pointer-events-none transition-opacity z-50 normal-case font-normal text-zinc-400 leading-tight text-[10px]">
                    Base fee: {(baseFee * 100).toFixed(2)}%
                </div>
            </div>

            {/* Open Interest */}
            <div className="flex items-center gap-1.5 px-2 py-1 bg-zinc-900/50 rounded border border-zinc-800/50 hover:bg-zinc-800 transition-colors cursor-help group relative">
                <Activity className="w-3 h-3 text-purple-500" />
                <span>OI</span>
                <span className="text-zinc-300 font-mono">{totalOI.toFixed(2)}</span>

                {/* OI Bar */}
                <div className="absolute top-full mt-2 left-0 w-48 p-2 bg-black border border-zinc-800 rounded opacity-0 group-hover:opacity-100 pointer-events-none transition-opacity z-50 normal-case font-normal text-zinc-400 leading-tight text-[10px]">
                    <div className="mb-2">Long/Short Ratio</div>
                    <div className="flex h-2 rounded overflow-hidden bg-zinc-900">
                        <div
                            className="bg-emerald-500"
                            style={{ width: `${oiRatio * 100}%` }}
                        />
                        <div
                            className="bg-red-500"
                            style={{ width: `${(1 - oiRatio) * 100}%` }}
                        />
                    </div>
                    <div className="flex justify-between mt-1 text-[9px]">
                        <span className="text-emerald-400">Long: {totalLong.toFixed(2)}</span>
                        <span className="text-red-400">Short: {totalShort.toFixed(2)}</span>
                    </div>
                </div>
            </div>
        </div>
    );
};
