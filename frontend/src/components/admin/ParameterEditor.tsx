import { useState } from 'react';
import { useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { Settings, Save, Loader2 } from 'lucide-react';

export const ParameterEditor = () => {

    // Local state for form inputs (defaults would ideally come from contract read)
    const [baseFee, setBaseFee] = useState('0.01'); // 1%
    const [volatilityMultiplier, setVolatilityMultiplier] = useState('1.5');

    // contractAddress and ABI would be used here in a real implementation
    const { data: hash, isPending } = useWriteContract();

    const { isLoading: isConfirming } = useWaitForTransactionReceipt({
        hash,
    });

    const handleUpdate = (e: React.FormEvent) => {
        e.preventDefault();
        // Update call - replace with actual function and params
        /*
        writeContract({
            address: contractAddress as `0x${string}`,
            abi: ORDERBOOK_ABI,
            functionName: 'updateFeeParameters',
            args: [parseEther(baseFee), parseEther(volatilityMultiplier)]
        });
        */
        console.log('Update parameters:', baseFee, volatilityMultiplier);
    };

    return (
        <div className="p-6 bg-slate-900 rounded-xl border border-slate-700">
            <h3 className="text-lg font-bold text-slate-200 mb-6 flex items-center gap-2">
                <Settings className="w-5 h-5 text-purple-400" /> System Parameters
            </h3>

            <form onSubmit={handleUpdate} className="space-y-4">
                <div>
                    <label className="block text-xs font-medium text-slate-400 mb-1">
                        Base Fee (%)
                    </label>
                    <input
                        type="number"
                        step="0.01"
                        value={baseFee}
                        onChange={(e) => setBaseFee(e.target.value)}
                        className="w-full bg-slate-950 border border-slate-800 rounded px-3 py-2 text-white focus:border-purple-500 focus:outline-none transition-colors"
                    />
                </div>

                <div>
                    <label className="block text-xs font-medium text-slate-400 mb-1">
                        Volatility Multiplier
                    </label>
                    <input
                        type="number"
                        step="0.1"
                        value={volatilityMultiplier}
                        onChange={(e) => setVolatilityMultiplier(e.target.value)}
                        className="w-full bg-slate-950 border border-slate-800 rounded px-3 py-2 text-white focus:border-purple-500 focus:outline-none transition-colors"
                    />
                </div>

                <div className="pt-2">
                    <button
                        type="submit"
                        disabled={isPending || isConfirming}
                        className="w-full py-2 bg-purple-600 hover:bg-purple-500 text-white font-bold rounded flex items-center justify-center transition-colors disabled:opacity-50"
                    >
                        {isPending || isConfirming ? (
                            <>
                                <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                                Updating...
                            </>
                        ) : (
                            <>
                                <Save className="w-4 h-4 mr-2" />
                                Save Changes
                            </>
                        )}
                    </button>
                </div>
            </form>
        </div>
    );
};
