import { Suspense } from "react";

import { DashboardMetrics } from "@/components/admin/dashboard-metrics";
import { DashboardSkeleton } from "@/components/admin/dashboard-skeleton";
import { RefreshButton } from "@/components/admin/refresh-button";

export default function DashboardPage() {
  return (
    <div className="flex flex-1 flex-col">
      <div className="flex justify-end px-6 pt-4">
        <RefreshButton />
      </div>
      <Suspense fallback={<DashboardSkeleton />}>
        <DashboardMetrics />
      </Suspense>
    </div>
  );
}
