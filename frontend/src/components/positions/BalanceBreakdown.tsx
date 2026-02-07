import { useBalance } from 'wagmi';
import { useAccount } from 'wagmi';
import { formatEther, erc20Abi } from 'viem';
import { PieChart, Pie, Cell, ResponsiveContainer, Tooltip } from 'recharts';
import { useReadContract } from 'wagmi';

// Token addresses from environment
const USDC_ADDRESS = import.meta.env.VITE_TOKEN1_ADDRESS as `0x${string}` | undefined;
const WETH_ADDRESS = import.meta.env.VITE_TOKEN0_ADDRESS as `0x${string}` | undefined;

export const BalanceBreakdown = () => {
    const { address } = useAccount();

    // 1. Get ETH Balance
    const { data: ethBalance } = useBalance({ address });

    // 2. Get USDC Balance (using env token address)
    const { data: usdcBalanceRaw } = useReadContract({
        address: USDC_ADDRESS,
        abi: erc20Abi,
        functionName: 'balanceOf',
        args: address ? [address] : undefined,
        query: {
            enabled: !!address && !!USDC_ADDRESS
        }
    }) as { data: bigint | undefined };

    // 3. Get WETH Balance (using env token address)
    const { data: wethBalanceRaw } = useReadContract({
        address: WETH_ADDRESS,
        abi: erc20Abi,
        functionName: 'balanceOf',
        args: address ? [address] : undefined,
        query: {
            enabled: !!address && !!WETH_ADDRESS
        }
    }) as { data: bigint | undefined };

    // Parse values
    const ethVal = ethBalance ? parseFloat(formatEther(ethBalance.value)) : 0;
    // USDC has 6 decimals
    const usdcVal = usdcBalanceRaw ? Number(usdcBalanceRaw) / 1e6 : 0;
    // WETH has 18 decimals
    const wethVal = wethBalanceRaw ? parseFloat(formatEther(wethBalanceRaw)) : 0;

    const data = [
        { name: 'ETH', value: ethVal * 2000 }, // Estimate ETH value in USD
        { name: 'WETH', value: wethVal * 2000 },
        { name: 'USDC', value: usdcVal },
    ].filter(d => d.value > 0);

    const COLORS = ['#3b82f6', '#10b981', '#f59e0b'];

    if (data.length === 0) {
        return (
            <div className="p-4 bg-zinc-900/10 rounded-lg border border-zinc-800/50 text-center text-zinc-500 text-xs italic">
                No assets found
            </div>
        )
    }

    return (
        <div className="p-4 bg-zinc-900/10 rounded-lg border border-zinc-800/50">
            <h3 className="text-[10px] font-bold text-zinc-500 mb-4 uppercase tracking-widest">Portfolio</h3>
            <div className="h-[150px]">
                <ResponsiveContainer width="100%" height="100%">
                    <PieChart>
                        <Pie
                            data={data}
                            cx="50%"
                            cy="50%"
                            innerRadius={40}
                            outerRadius={60}
                            paddingAngle={5}
                            dataKey="value"
                            stroke="none"
                        >
                            {data.map((_, index) => (
                                <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                            ))}
                        </Pie>
                        <Tooltip
                            contentStyle={{ backgroundColor: '#09090b', borderColor: '#27272a', fontSize: '12px' }}
                            itemStyle={{ color: '#e4e4e7' }}
                            formatter={(value: number | undefined) => [`$${(value || 0).toFixed(2)}`, 'Value']}
                        />
                    </PieChart>
                </ResponsiveContainer>
            </div>
            <div className="flex justify-center gap-4 mt-2">
                {data.map((entry, index) => (
                    <div key={entry.name} className="flex items-center gap-2">
                        <div className="w-2 h-2 rounded-full" style={{ backgroundColor: COLORS[index % COLORS.length] }} />
                        <span className="text-xs font-mono text-zinc-400">{entry.name}</span>
                    </div>
                ))}
            </div>
        </div>
    );
};
