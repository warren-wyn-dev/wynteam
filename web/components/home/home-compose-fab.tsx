"use client";

import Link from "next/link";

import { WynosIcon } from "@/components/ui/wynos-icon";

/**
 * X-style quick compose for immersive Home scrolling. The Home header's
 * scroll controller toggles the root class that reveals this link exactly
 * when both navigation bars are hidden. Uses the same route as the existing
 * bottom-nav Post action, so it opens the same composer without a second
 * composer implementation.
 */
export function HomeComposeFab() {
  return (
    <Link
      className="wyn-home-compose-fab"
      href="/?compose=1"
      scroll={false}
      aria-label="สร้างโพสต์ใหม่"
      onPointerDown={() => { void import("@/components/beta4-composer"); }}
    >
      <WynosIcon name="post" size={28} strokeWidth={2} />
    </Link>
  );
}
