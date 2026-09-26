"use client";

import { AnimatePresence, motion, useReducedMotion } from "framer-motion";
import { useState } from "react";

const countVariants = {
  enter: (direction: number) => ({ y: direction > 0 ? "110%" : "-110%", opacity: 0 }),
  center: { y: "0%", opacity: 1 },
  exit: (direction: number) => ({ y: direction > 0 ? "-110%" : "110%", opacity: 0 }),
};

/**
 * One shared metric transition for Feed, Profile and Post Detail.
 * An increase rolls upward; a decrease rolls downward. Only a changed
 * value animates, so an unrelated post re-render never replays the motion.
 */
export function AnimatedCount({
  value,
  hideZero = false,
  className,
}: {
  value: number;
  hideZero?: boolean;
  className?: string;
}) {
  // React permits a conditional previous-prop adjustment during render;
  // this avoids reading mutable refs in render and keeps direction current.
  const [previous, setPrevious] = useState(value);
  const [direction, setDirection] = useState(1);
  if (value !== previous) {
    setDirection(value > previous ? 1 : -1);
    setPrevious(value);
  }
  const reduceMotion = useReducedMotion();

  const visible = !hideZero || value > 0;

  return (
    <span
      className={["wyn-animated-count", className ?? ""].filter(Boolean).join(" ")}
      data-direction={direction > 0 ? "up" : "down"}
      aria-hidden="true"
      style={{
        display: visible ? "inline-grid" : "none",
        position: "relative",
        alignItems: "center",
        overflow: "hidden",
        verticalAlign: "baseline",
        fontVariantNumeric: "tabular-nums",
      }}
    >
      <AnimatePresence initial={false} custom={direction}>
        {visible ? (
          <motion.span
            key={value}
            custom={direction}
            variants={countVariants}
            initial={reduceMotion ? false : "enter"}
            animate="center"
            exit={reduceMotion ? undefined : "exit"}
            transition={{ duration: reduceMotion ? 0 : 0.22, ease: "easeOut" }}
            style={{ gridArea: "1 / 1", display: "inline-block", whiteSpace: "nowrap", lineHeight: "inherit" }}
          >
            {value}
          </motion.span>
        ) : null}
      </AnimatePresence>
    </span>
  );
}
