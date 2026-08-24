"use client";

import { Button } from "@/components/ui/button";

/**
 * Catches a failed data fetch anywhere under the (admin) route group
 * (currently just Dashboard's admin_dashboard_metrics() call) --
 * Design spec's Screen "Error" state: replace the content with a
 * message + retry button, not a blank page or a stack trace.
 */
export default function AdminError({ reset }: { error: Error; reset: () => void }) {
  return (
    <div className="flex flex-1 flex-col items-center justify-center gap-4 p-6">
      <p className="text-muted-foreground">โหลดข้อมูลไม่สำเร็จ</p>
      <Button onClick={reset}>ลองใหม่</Button>
    </div>
  );
}
