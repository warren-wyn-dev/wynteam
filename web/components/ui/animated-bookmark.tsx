"use client";

import { motion, useAnimationControls, useReducedMotion } from "framer-motion";
import { useEffect, useRef } from "react";

import { SaveIcon } from "@/components/ui/post-action-icons";

/** Use the existing WYNOS bookmark artwork; animate only a real state change. */
export function AnimatedBookmark({
  saved,
  size = 22,
  strokeWidth = 2,
}: {
  saved: boolean;
  size?: number;
  strokeWidth?: number;
}) {
  const controls = useAnimationControls();
  const previous = useRef(saved);
  const reduceMotion = useReducedMotion();

  useEffect(() => {
    if (saved !== previous.current && !reduceMotion) {
      void controls.start({
        scale: saved ? [1, 0.87, 1.14, 1] : [1, 1.08, 0.94, 1],
        transition: { duration: 0.24, ease: "easeOut" },
      });
    }
    previous.current = saved;
  }, [saved, controls, reduceMotion]);

  return (
    <motion.span animate={controls} style={{ display: "inline-flex", transformOrigin: "center" }}>
      <SaveIcon saved={saved} size={size} strokeWidth={strokeWidth} />
    </motion.span>
  );
}
