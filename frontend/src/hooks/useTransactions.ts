import { useWaitForTransactionReceipt } from 'wagmi';
import { useEffect } from 'react';

// Simple toast placeholder - replace with actual toast library usage
const notify = (msg: string, type: 'success' | 'error' | 'loading') => {
    console.log(`[Toast ${type}] ${msg}`);
};

export function useTransactionStatus(hash: `0x${string}` | undefined) {
    const { isLoading, isSuccess, isError, error } = useWaitForTransactionReceipt({
        hash,
    });

    useEffect(() => {
        if (isLoading) {
            notify('Transaction pending...', 'loading');
        }
    }, [isLoading]);

    useEffect(() => {
        if (isSuccess) {
            notify('Transaction confirmed!', 'success');
        }
    }, [isSuccess]);

    useEffect(() => {
        if (isError) {
            notify(`Transaction failed: ${error?.message}`, 'error');
        }
    }, [isError, error]);

    useEffect(() => {
        if (hash) {
            const stored = localStorage.getItem('tx_history');
            const history = stored ? JSON.parse(stored) : [];
            if (!history.find((h: any) => h.hash === hash)) {
                history.push({ hash, timestamp: Date.now(), status: 'pending' });
                localStorage.setItem('tx_history', JSON.stringify(history));
            }
        }
    }, [hash]);

    return { isLoading, isSuccess, isError };
}
