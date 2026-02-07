import { useOrderbook } from '../../hooks/useOrderbook';
import { useOrderbookStore } from '../../stores/orderbookStore';
import { OrderbookRow } from './OrderbookRow';
import { SpreadIndicator } from './SpreadIndicator';
import { Loader2, AlertCircle } from 'lucide-react';

export const OrderbookView = () => {
    const { isLoading, error } = useOrderbook();
    const { bids, asks, spread, midPrice } = useOrderbookStore();

    // Find max volume for depth visualization relative sizing
    const maxBidVol = bids.reduce((acc, curr) => acc > curr.quantity ? acc : curr.quantity, 0n);
    const maxAskVol = asks.reduce((acc, curr) => acc > curr.quantity ? acc : curr.quantity, 0n);
    const maxVol = maxBidVol > maxAskVol ? maxBidVol : maxAskVol;

    const handlePriceClick = (price: bigint) => {
        console.log('Price clicked:', price);
        // Connect to order form pre-fill
    };

    if (isLoading && bids.length === 0 && asks.length === 0) {
        return (
            <div className="flex items-center justify-center h-96 bg-slate-900 rounded-xl border border-slate-800">
                <Loader2 className="w-8 h-8 text-blue-500 animate-spin" />
            </div>
        );
    }

    if (error) {
        return (
            <div className="flex flex-col items-center justify-center h-96 bg-slate-900 rounded-xl border border-slate-800 text-red-400 p-4 text-center">
                <AlertCircle className="w-8 h-8 mb-2" />
                <p>Failed to load orderbook</p>
                <p className="text-sm text-slate-500 mt-1">{error?.message || 'Unknown error'}</p>
            </div>
        );
    }

    return (
        <div className="flex flex-col h-full bg-black overflow-hidden font-mono text-xs">
            {/* Header */}
            <div className="flex flex-none justify-between px-2 py-2 bg-black border-b border-zinc-800 text-zinc-500 uppercase tracking-wider">
                <div className="w-1/3 text-left">Price (ETH)</div>
                <div className="w-1/3 text-right">Size</div>
                <div className="w-1/3 text-right">Total</div>
            </div>

            {/* Asks (Sell Orders) - Red - Reverse order to show lowest ask at bottom */}
            <div className="flex-1 overflow-y-auto scrollbar-none flex flex-col-reverse relative">
                {/* Depth visualizer background */}
                {asks.length === 0 ? (
                    <div className="flex items-end justify-center h-full pb-4 text-zinc-600">No Asks</div>
                ) : (
                    asks.map((level) => (
                        <OrderbookRow
                            key={level.price.toString()}
                            level={level}
                            type="ask"
                            maxTotal={maxVol}
                            onClick={handlePriceClick}
                        />
                    ))
                )}
            </div>

            {/* Spread Indicator - Compact */}
            <div className="flex-none bg-black">
                <SpreadIndicator spread={spread} midPrice={midPrice} />
            </div>

            {/* Bids (Buy Orders) - Green */}
            <div className="flex-1 overflow-y-auto scrollbar-none">
                {bids.length === 0 ? (
                    <div className="flex items-start justify-center h-full pt-4 text-zinc-600">No Bids</div>
                ) : (
                    bids.map((level) => (
                        <OrderbookRow
                            key={level.price.toString()}
                            level={level}
                            type="bid"
                            maxTotal={maxVol}
                            onClick={handlePriceClick}
                        />
                    ))
                )}
            </div>
        </div>
    );
};
