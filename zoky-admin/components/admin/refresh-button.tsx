"use client";

import { useTransition } from "react";
import { useRouter } from "next/navigation";
import { RefreshCw } from "lucide-react";

import { Button } from "@/components/ui/button";

/**
 * `router.refresh()` inside startTransition re-runs the Server
 * Component data fetch for the current route without a full
 * navigation -- React keeps the already-rendered (stale) numbers
 * visible during the transition instead of falling back to the
 * Suspense skeleton again, which is exactly the Design spec's
 * "Refreshing" state ("ตัวเลขเดิมยังแสดงอยู่ ... แค่ปุ่มรีเฟรช disabled+spin").
 */
export function RefreshButton() {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();

  return (
    <Button
      type="button"
      variant="outline"
      size="sm"
      disabled={isPending}
      aria-busy={isPending}
      onClick={() => startTransition(() => router.refresh())}
    >
      <RefreshCw className={isPending ? "animate-spin" : undefined} />
      รีเฟรช
    </Button>
  );
}
