import { useChainId, useSwitchChain } from 'wagmi';
import { Loader2, ChevronDown, Network } from 'lucide-react';
import { useState, useRef, useEffect } from 'react';
import clsx from 'clsx';

export const NetworkSwitcher = () => {
    const chainId = useChainId();
    const { chains, switchChain, isPending } = useSwitchChain();
    const [isOpen, setIsOpen] = useState(false);
    const dropdownRef = useRef<HTMLDivElement>(null);

    const currentChain = chains.find(x => x.id === chainId);

    useEffect(() => {
        const handleClickOutside = (event: MouseEvent) => {
            if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
                setIsOpen(false);
            }
        };
        document.addEventListener('mousedown', handleClickOutside);
        return () => document.removeEventListener('mousedown', handleClickOutside);
    }, []);

    return (
        <div className="relative" ref={dropdownRef}>
            <button
                onClick={() => setIsOpen(!isOpen)}
                className="flex items-center gap-2 px-3 py-1.5 bg-zinc-900/50 hover:bg-zinc-900 border border-zinc-800 rounded-lg transition-colors text-sm font-medium text-zinc-300"
            >
                <Network className="w-4 h-4 text-zinc-500" />
                <span className="hidden sm:inline">{currentChain?.name || 'Unknown Network'}</span>
                <ChevronDown className={clsx("w-3 h-3 text-zinc-500 transition-transform", isOpen && "rotate-180")} />
            </button>

            {isOpen && (
                <div className="absolute right-0 top-full mt-2 w-56 z-50 bg-black border border-zinc-800 rounded-xl shadow-xl shadow-black/50 p-2 flex flex-col gap-1">
                    <div className="px-2 py-1.5 text-xs font-bold text-zinc-500 uppercase tracking-wider border-b border-zinc-900 mb-1">
                        Select Network
                    </div>
                    {chains.map((x) => (
                        <button
                            key={x.id}
                            onClick={() => {
                                switchChain({ chainId: x.id });
                                setIsOpen(false);
                            }}
                            disabled={isPending || x.id === chainId}
                            className={clsx(
                                "flex items-center justify-between px-3 py-2 rounded-lg text-sm transition-colors text-left",
                                x.id === chainId
                                    ? "bg-zinc-900 text-white"
                                    : "text-zinc-400 hover:bg-zinc-800 hover:text-zinc-200"
                            )}
                        >
                            <span>{x.name}</span>
                            {isPending && x.id === chainId && <Loader2 className="w-3 h-3 animate-spin" />}
                            {x.id === currentChain?.id && !isPending && <div className="w-1.5 h-1.5 rounded-full bg-emerald-500" />}
                        </button>
                    ))}
                </div>
            )}
        </div>
    );
};
