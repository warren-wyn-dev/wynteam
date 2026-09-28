"use client";

import { motion, useAnimationControls } from "framer-motion";
import { useEffect, useRef } from "react";

/**
 * WYNOS Beta 2 preview — social heart with Threads-like proportions.
 * Keeps the existing WYNOS interaction size and like animation.
 */
export function AnimatedHeart({
  size = 24,
  strokeWidth = 2,
  liked,
}: {
  size?: number;
  strokeWidth?: number;
  liked: boolean;
}) {
  const controls = useAnimationControls();
  const wasLiked = useRef(liked);

  useEffect(() => {
    if (liked && !wasLiked.current) {
      void controls.start({
        scale: [1, 1.3, 0.96, 1.05, 1],
        transition: { duration: 0.36, ease: "easeOut" },
      });
    }
    wasLiked.current = liked;
  }, [liked, controls]);

  return (
    <motion.span style={{ display: "inline-flex" }} animate={controls}>
      <svg
        width={size}
        height={size}
        viewBox="0 0 24 24"
        fill={liked ? "currentColor" : "none"}
        stroke="currentColor"
        strokeWidth={strokeWidth}
        strokeLinecap="round"
        strokeLinejoin="round"
        aria-hidden="true"
      >
        <path d="M12 20.55c-.3 0-.58-.09-.82-.26C5.45 16.32 2.6 13.5 2.6 9.78 2.6 6.45 4.97 4.08 8.1 4.08c1.64 0 3.03.73 3.9 1.92.87-1.19 2.26-1.92 3.9-1.92 3.13 0 5.5 2.37 5.5 5.7 0 3.72-2.85 6.54-8.58 10.51-.24.17-.52.26-.82.26Z" />
      </svg>
    </motion.span>
  );
}
