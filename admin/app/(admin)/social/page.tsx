import { Suspense } from "react";

import { DashboardMetrics } from "@/components/admin/dashboard-metrics";
import { DashboardSkeleton } from "@/components/admin/dashboard-skeleton";
import { RefreshButton } from "@/components/admin/refresh-button";

/** The original Admin dashboard remains intact, now scoped to WYNOS Social. */
export default function SocialDashboardPage() {
  return (
    <div className="flex flex-1 flex-col">
      <div className="flex flex-wrap items-center justify-between gap-3 px-6 pt-6">
        <div>
          <h2 className="text-xl font-semibold">แดชบอร์ด WYNOS Social</h2>
          <p className="mt-1 text-sm text-muted-foreground">
            ภาพรวมผู้ใช้งาน เนื้อหา และการมีส่วนร่วมบน wynos.online
          </p>
        </div>
        <RefreshButton />
      </div>
      <Suspense fallback={<DashboardSkeleton />}>
        <DashboardMetrics />
      </Suspense>
    </div>
  );
}
