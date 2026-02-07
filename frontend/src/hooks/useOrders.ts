import { useCallback } from 'react';
import { useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { parseEther } from 'viem';
import { FLOW_HOOK_ROUTER_ABI, VAMM_ENGINE_ABI, getContractAddress, getVAMMEngineAddress } from '../lib/contracts';
import { useChainId } from 'wagmi';
import { useCurveMode, CurveMode } from './useCurveMode';

export function useOrders() {
    const chainId = useChainId();
    const contractAddress = getContractAddress(chainId);
    const vammEngineAddress = getVAMMEngineAddress(chainId);
    const { mode } = useCurveMode();

    const {
        data: hash,
        writeContract,
        isPending: isWritePending,
        error: writeError
    } = useWriteContract();

    const {
        isLoading: isConfirming,
        isSuccess: isConfirmed,
        error: receiptError
    } = useWaitForTransactionReceipt({
        hash,
    });

    const placeOrder = useCallback((isBuy: boolean, price: string, quantity: string) => {
        if (!contractAddress) return;

        // Note: In a real app, you might need to approve tokens first if not using native ETH
        // For this hook, assuming we are sending ETH for buys if it's an orderbook for ETH/Token
        // or using WETH. The contract interface usually dictates this.
        // Based on standard implementation:
        // Buys usually require sending ETH (msg.value) or approving ERC20.
        // Let's assume standard interaction based on the ABI we saw earlier (standard addOrder).

        // CAUTION: You need to know if the contract expects raw values or scaled 1e18.
        // Usually DeFi expects 1e18.

        try {
            const priceWei = parseEther(price);
            const quantityWei = parseEther(quantity);

            if (mode === CurveMode.LOB) {
                // Place Limit Order
                writeContract({
                    address: contractAddress as `0x${string}`,
                    abi: FLOW_HOOK_ROUTER_ABI,
                    functionName: 'placeLimitOrder',
                    args: [priceWei, quantityWei, isBuy],
                });
            } else {
                // Execute VAMM Trade (Market Order)
                writeContract({
                    address: vammEngineAddress as `0x${string}`,
                    abi: VAMM_ENGINE_ABI,
                    functionName: 'executeTrade',
                    args: [quantityWei, isBuy],
                });
            }
        } catch (e) {
            console.error("Error preparing transaction:", e);
        }
    }, [contractAddress, writeContract]);

    const cancelOrder = useCallback((orderId: bigint) => {
        if (!contractAddress) return;

        writeContract({
            address: contractAddress as `0x${string}`,
            abi: FLOW_HOOK_ROUTER_ABI,
            functionName: 'cancelOrder',
            args: [orderId],
        });
    }, [contractAddress, writeContract]);

    return {
        placeOrder,
        cancelOrder,
        isPending: isWritePending || isConfirming,
        isConfirmed,
        hash,
        error: writeError || receiptError,
    };
}
