import { ConnectButton } from '@rainbow-me/rainbowkit';
import { useConnect } from 'wagmi';
import { injected } from 'wagmi/connectors';
import { Zap } from 'lucide-react';

export const WalletConnect = () => {
    const { connect } = useConnect();

    return (
        <ConnectButton.Custom>
            {({
                account,
                chain,
                openAccountModal,
                openChainModal,
                openConnectModal,
                authenticationStatus,
                mounted,
            }) => {
                const ready = mounted && authenticationStatus !== 'loading';
                const connected =
                    ready &&
                    account &&
                    chain &&
                    (!authenticationStatus ||
                        authenticationStatus === 'authenticated');

                return (
                    <div
                        {...(!ready && {
                            'aria-hidden': true,
                            'style': {
                                opacity: 0,
                                pointerEvents: 'none',
                                userSelect: 'none',
                            },
                        })}
                        className="flex items-center gap-2"
                    >
                        {(() => {
                            if (!connected) {
                                return (
                                    <>
                                        {/* Direct MetaMask Button (Fallback) */}
                                        <button
                                            onClick={() => connect({ connector: injected() })}
                                            type="button"
                                            className="bg-orange-500/10 hover:bg-orange-500/20 text-orange-500 border border-orange-500/50 font-bold py-2 px-3 rounded-lg transition-colors text-xs flex items-center gap-2"
                                            title="Direct MetaMask Connection (Bypass RainbowKit)"
                                        >
                                            <Zap size={14} />
                                            Direct
                                        </button>

                                        {/* Standard RainbowKit Button */}
                                        <button
                                            onClick={openConnectModal}
                                            type="button"
                                            className="bg-gradient-to-r from-emerald-500 to-emerald-600 hover:from-emerald-400 hover:to-emerald-500 text-black font-bold py-2 px-4 rounded-lg transition-all text-sm shadow-lg shadow-emerald-500/20"
                                        >
                                            Connect Wallet
                                        </button>
                                    </>
                                );
                            }

                            if (chain.unsupported) {
                                return (
                                    <button
                                        onClick={openChainModal}
                                        type="button"
                                        className="bg-red-500/10 hover:bg-red-500/20 text-red-500 border border-red-500/50 font-bold py-1.5 px-3 rounded-lg transition-colors text-sm"
                                    >
                                        Wrong Network
                                    </button>
                                );
                            }

                            return (
                                <div style={{ display: 'flex', gap: 8 }}>
                                    <button
                                        onClick={openAccountModal}
                                        type="button"
                                        className="bg-zinc-900/50 hover:bg-zinc-900 text-zinc-200 font-medium py-1.5 px-3 rounded-lg transition-colors border border-zinc-800 flex items-center gap-2 text-sm"
                                    >
                                        <div className="w-2 h-2 rounded-full bg-emerald-500" />
                                        {account.displayName}
                                    </button>
                                </div>
                            );
                        })()}
                    </div>
                );
            }}
        </ConnectButton.Custom>
    );
};
