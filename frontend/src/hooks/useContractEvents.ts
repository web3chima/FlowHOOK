import { useWatchContractEvent, useChainId } from 'wagmi';
import { ORDERBOOK_ABI, getContractAddress } from '../lib/contracts';

type EventCallback = (logs: any[]) => void;

/**
 * Hook to watch FlowHook contract events
 * Supports SwapExecuted and ModeChanged events from the modular contracts
 */
export function useContractEvents({
    onSwapExecuted,
    onModeChanged,
}: {
    onSwapExecuted?: EventCallback;
    onModeChanged?: EventCallback;
}) {
    const chainId = useChainId();
    const address = getContractAddress(chainId);

    // Watch SwapExecuted events
    useWatchContractEvent({
        address: address as `0x${string}`,
        abi: ORDERBOOK_ABI,
        eventName: 'SwapExecuted',
        onLogs: (logs) => onSwapExecuted?.(logs),
        enabled: !!address && !!onSwapExecuted,
    });

    // Watch ModeChanged events
    useWatchContractEvent({
        address: address as `0x${string}`,
        abi: ORDERBOOK_ABI,
        eventName: 'ModeChanged',
        onLogs: (logs) => onModeChanged?.(logs),
        enabled: !!address && !!onModeChanged,
    });
}

/**
 * Legacy hook for backwards compatibility
 * Maps old event names to new ones
 */
export function useLegacyContractEvents({
    onOrderPlaced,
    onOrderMatched,
    onOrderCancelled,
    onSwapExecuted,
}: {
    onOrderPlaced?: EventCallback;
    onOrderMatched?: EventCallback;
    onOrderCancelled?: EventCallback;
    onSwapExecuted?: EventCallback;
}) {
    // In VAMM mode, there are no order events
    // We only support SwapExecuted
    useContractEvents({
        onSwapExecuted,
    });

    // Log deprecation warning for order events
    if (onOrderPlaced || onOrderMatched || onOrderCancelled) {
        console.warn(
            'Order events (OrderPlaced, OrderMatched, OrderCancelled) are not available in VAMM mode. ' +
            'These events are only available in LOB/HYBRID modes.'
        );
    }
}
