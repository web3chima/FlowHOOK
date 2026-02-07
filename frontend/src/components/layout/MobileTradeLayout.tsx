import { useState } from 'react';
import { clsx } from 'clsx';
import { X, TrendingUp, TrendingDown } from 'lucide-react';

interface MobileTradeLayoutProps {
    header: React.ReactNode;
    chart: React.ReactNode;
    orderbook: React.ReactNode;
    orderForm: React.ReactNode; // Content for the Drawer
    history: React.ReactNode;
}

export const MobileTradeLayout = ({ header, chart, orderbook, orderForm, history }: MobileTradeLayoutProps) => {
    const [isDrawerOpen, setIsDrawerOpen] = useState(false);
    const [tradeSide, setTradeSide] = useState<'buy' | 'sell'>('buy');

    const openDrawer = (side: 'buy' | 'sell') => {
        setTradeSide(side);
        setIsDrawerOpen(true);
    };

    return (
        <div className="w-full max-w-full flex flex-col h-[100dvh] bg-black text-zinc-200 overflow-hidden relative">
            {/* 1. Header & Chart Area */}
            <div className="flex-none px-3 sm:px-4 pt-3 sm:pt-4 pb-0 z-40 relative"> {/* Added z-40 relative for header interaction */}
                {header}
            </div>

            <div className="h-[30vh] sm:h-[35vh] flex-none border-b border-zinc-900 shrink-0">
                {chart}
            </div>

            {/* 2. Scrollable Content (Orderbook + History) */}
            <div className="flex-1 overflow-y-auto pb-32 min-h-0 relative z-0"> {/* min-h-0 is crucial for flex child scrolling */}
                {/* Orderbook Preview */}
                <div className="p-4 border-b border-zinc-900">
                    <h3 className="text-xs font-bold text-zinc-500 uppercase mb-2">Orderbook</h3>
                    {orderbook}
                </div>

                {/* History Preview */}
                <div className="p-4 relative">
                    <h3 className="text-xs font-bold text-zinc-500 uppercase mb-2">Your Positions</h3>
                    {history}
                </div>
            </div>

            {/* 3. Bottom Fixed Action Bar */}
            <div className="fixed bottom-0 left-0 right-0 px-3 sm:px-4 py-3 sm:py-4 bg-black/90 backdrop-blur-md border-t border-zinc-800 flex gap-2 sm:gap-3 z-30 safe-area-pb">
                <button
                    onClick={() => openDrawer('buy')}
                    className="flex-1 bg-gradient-to-r from-emerald-500 to-emerald-600 hover:from-emerald-400 hover:to-emerald-500 text-black text-sm sm:text-base font-bold h-11 sm:h-12 rounded-lg flex items-center justify-center gap-2 active:scale-95 transition-all shadow-lg shadow-emerald-500/20"
                >
                    Buy / Long
                </button>
                <button
                    onClick={() => openDrawer('sell')}
                    className="flex-1 bg-gradient-to-r from-red-500 to-red-600 hover:from-red-400 hover:to-red-500 text-white text-sm sm:text-base font-bold h-11 sm:h-12 rounded-lg flex items-center justify-center gap-2 active:scale-95 transition-all shadow-lg shadow-red-500/20"
                >
                    Sell / Short
                </button>
            </div>

            {/* 4. Slide-up Drawer (OrderForm) */}
            <div
                className={clsx(
                    "fixed inset-0 z-50 bg-black/60 backdrop-blur-sm transition-opacity duration-300",
                    isDrawerOpen ? "opacity-100 pointer-events-auto" : "opacity-0 pointer-events-none"
                )}
                onClick={() => setIsDrawerOpen(false)}
            />
            <div
                className={clsx(
                    "fixed bottom-0 left-0 right-0 bg-zinc-900 border-t border-zinc-800 rounded-t-2xl z-50 transition-transform duration-300 ease-out transform max-h-[85vh] overflow-y-auto",
                    isDrawerOpen ? "translate-y-0" : "translate-y-full"
                )}
            >
                <div className="sticky top-0 bg-zinc-900 p-4 border-b border-zinc-800 flex items-center justify-between">
                    <h2 className="text-lg font-bold text-white flex items-center gap-2">
                        {tradeSide === 'buy' ? <TrendingUp className="text-green-500" /> : <TrendingDown className="text-red-500" />}
                        {tradeSide === 'buy' ? 'Long ETH' : 'Short ETH'}
                    </h2>
                    <button onClick={() => setIsDrawerOpen(false)} className="p-2 bg-zinc-800 rounded-full text-zinc-400">
                        <X size={20} />
                    </button>
                </div>
                <div className="p-4 pb-8">
                    {/* We can inject the trade side prop into the form if needed, or user handles it in the form ui */}
                    {orderForm}
                </div>
            </div>
        </div>
    );
};
