"use client";

import { useState } from "react";

import { merchantMenuThumbnailUrl } from "@/lib/merchant-menu-image";

/**
 * Customer-facing food/store photo (menu items, store covers and logos). Public Supabase images go through the project's
 * existing /_next/image optimizer at a small width (originals are full camera
 * photos); if the optimizer fails, the original URL is used instead.
 */
export function FoodPhoto({
  src,
  width,
  loading,
  fetchPriority,
}: {
  src: string;
  width: 128 | 256 | 384 | 750;
  loading?: "lazy" | "eager";
  fetchPriority?: "high" | "low" | "auto";
}) {
  const optimized = merchantMenuThumbnailUrl(src, process.env.NEXT_PUBLIC_SUPABASE_URL, width) ?? src;
  const [failed, setFailed] = useState(false);
  return (
    // eslint-disable-next-line @next/next/no-img-element
    <img
      src={failed ? src : optimized}
      alt=""
      loading={loading}
      decoding="async"
      fetchPriority={fetchPriority}
      onError={() => { if (!failed && optimized !== src) setFailed(true); }}
    />
  );
}
