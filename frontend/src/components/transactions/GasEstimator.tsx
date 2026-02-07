import { Fuel } from 'lucide-react';

interface GasEstimatorProps {
    estimatedGas?: string;
}

export const GasEstimator = ({ estimatedGas = '0.00042' }: GasEstimatorProps) => {
    return (
        <div className="flex items-center gap-2 text-xs text-slate-500 mt-2">
            <Fuel className="w-3 h-3" />
            <span>Est. Gas: {estimatedGas} ETH</span>
        </div>
    );
};
