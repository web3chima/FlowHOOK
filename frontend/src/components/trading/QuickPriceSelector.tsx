interface QuickPriceSelectorProps {
    currentPrice: string;
    onSelectPrice: (price: string) => void;
}

export const QuickPriceSelector = ({ currentPrice, onSelectPrice }: QuickPriceSelectorProps) => {
    const priceNum = parseFloat(currentPrice) || 0;

    const adjustments = [
        { label: '-5%', value: 0.95 },
        { label: '-1%', value: 0.99 },
        { label: 'Mid', value: 1.0 },
        { label: '+1%', value: 1.01 },
        { label: '+5%', value: 1.05 },
    ];

    return (
        <div className="flex gap-2 mb-4 overflow-x-auto pb-2 scrollbar-none">
            {adjustments.map((adj) => (
                <button
                    key={adj.label}
                    onClick={() => onSelectPrice((priceNum * adj.value).toFixed(2))}
                    className="px-3 py-1 bg-slate-800 hover:bg-slate-700 text-xs text-slate-300 rounded-full transition-colors whitespace-nowrap"
                >
                    {adj.label}
                </button>
            ))}
        </div>
    );
};
