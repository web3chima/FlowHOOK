import React, { useState, useEffect, useRef, ReactNode } from 'react';
import { GripVertical } from 'lucide-react';
import clsx from 'clsx';

interface ResizableLayoutProps {
    leftPanel: ReactNode;
    middlePanel: ReactNode;
    rightPanel: ReactNode;
    initialLeftWidth?: number; // Check if percentage or pixels. Let's use percentage for responsiveness
    initialRightWidth?: number;
}

export const ResizableLayout = ({
    leftPanel,
    middlePanel,
    rightPanel,
    initialLeftWidth = 50, // 50%
    initialRightWidth = 25 // 25% (Middle gets remaining 25%)
}: ResizableLayoutProps) => {
    // Widths are in percentages
    const [leftWidth, setLeftWidth] = useState(initialLeftWidth);
    const [rightWidth, setRightWidth] = useState(initialRightWidth);

    // Limits
    const minPanelWidth = 15; // 15%
    const maxPanelWidth = 70; // 70%

    const containerRef = useRef<HTMLDivElement>(null);
    const isDraggingLeft = useRef(false);
    const isDraggingRight = useRef(false);

    // Handle Resize Logic
    useEffect(() => {
        const handleMouseMove = (e: MouseEvent) => {
            if (!containerRef.current) return;
            if (!isDraggingLeft.current && !isDraggingRight.current) return;

            const containerRect = containerRef.current.getBoundingClientRect();
            const containerWidth = containerRect.width;
            const mouseX = e.clientX - containerRect.left;

            // Percentage from left
            const mousePercent = (mouseX / containerWidth) * 100;

            if (isDraggingLeft.current) {
                // Moving the first splitter (Between Left and Middle)
                // New Left Width = mousePercent
                // Constraints: 
                // 1. Min/Max for Left
                // 2. Middle panel must maintain min width
                const newLeftWidth = Math.max(minPanelWidth, Math.min(mousePercent, maxPanelWidth));

                // Ensure Middle has space ( Total - Left - Right >= Min )
                if (100 - newLeftWidth - rightWidth >= minPanelWidth) {
                    setLeftWidth(newLeftWidth);
                }
            }

            if (isDraggingRight.current) {
                // Moving the second splitter (Between Middle and Right)
                // The split position is at (100 - RightWidth)%
                // Mouse is at mousePercent%
                // So RightWidth = 100 - mousePercent
                const newRightWidth = 100 - mousePercent;

                // Constraints:
                const safeRightWidth = Math.max(minPanelWidth, Math.min(newRightWidth, maxPanelWidth));

                // Ensure Middle has space
                if (100 - leftWidth - safeRightWidth >= minPanelWidth) {
                    setRightWidth(safeRightWidth);
                }
            }
        };

        const handleMouseUp = () => {
            isDraggingLeft.current = false;
            isDraggingRight.current = false;
            document.body.style.cursor = 'default';
            document.body.style.userSelect = 'auto'; // Re-enable selection
        };

        document.addEventListener('mousemove', handleMouseMove);
        document.addEventListener('mouseup', handleMouseUp);

        return () => {
            document.removeEventListener('mousemove', handleMouseMove);
            document.removeEventListener('mouseup', handleMouseUp);
        };
    }, [leftWidth, rightWidth]);

    const startDragLeft = () => {
        isDraggingLeft.current = true;
        document.body.style.cursor = 'col-resize';
        document.body.style.userSelect = 'none'; // Prevent text selection
    };

    const startDragRight = () => {
        isDraggingRight.current = true;
        document.body.style.cursor = 'col-resize';
        document.body.style.userSelect = 'none';
    };

    return (
        <div ref={containerRef} className="w-full h-full flex overflow-hidden">
            {/* Left Panel */}
            <div style={{ width: `${leftWidth}%` }} className="h-full min-w-0 flex flex-col">
                {leftPanel}
            </div>

            {/* Splitter 1 */}
            <div
                onMouseDown={startDragLeft}
                className="w-1 bg-zinc-900 border-l border-r border-zinc-800 hover:bg-blue-500 cursor-col-resize flex items-center justify-center shrink-0 transition-colors z-10"
            >
                <div className="h-8 w-0.5 bg-zinc-700/50 rounded-full" />
            </div>

            {/* Middle Panel */}
            <div style={{ width: `${100 - leftWidth - rightWidth}%` }} className="h-full min-w-0 flex flex-col">
                {middlePanel}
            </div>

            {/* Splitter 2 */}
            <div
                onMouseDown={startDragRight}
                className="w-1 bg-zinc-900 border-l border-r border-zinc-800 hover:bg-blue-500 cursor-col-resize flex items-center justify-center shrink-0 transition-colors z-10"
            >
                <div className="h-8 w-0.5 bg-zinc-700/50 rounded-full" />
            </div>

            {/* Right Panel */}
            <div style={{ width: `${rightWidth}%` }} className="h-full min-w-0 flex flex-col">
                {rightPanel}
            </div>
        </div>
    );
};
