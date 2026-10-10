import { Suspense } from "react";

import type { AuditLogEventType } from "@/lib/admin-audit-log";
import { EventTypeFilter } from "./event-type-filter";
import { AuditLogResults } from "./results";
import { NoAccess } from "@/components/admin/no-access";
import { requireAdminRole } from "@/lib/auth";

export default async function AuditLogPage({
  searchParams,
}: {
  searchParams: Promise<{ event_type?: string }>;
}) {
  const ctx = await requireAdminRole();
  if (!(ctx.access.superAdmin || !ctx.access.available)) return <NoAccess what="ดู Audit Log (เฉพาะ super admin)" />;
  const { event_type } = await searchParams;
  const eventType = (event_type ?? "all") as AuditLogEventType | "all";

  return (
    <div className="flex flex-col gap-4 p-6">
      <EventTypeFilter />
      <Suspense
        key={eventType}
        fallback={
          <div className="flex flex-col gap-2">
            {Array.from({ length: 6 }).map((_, i) => (
              <div key={i} className="h-14 animate-pulse rounded-lg border bg-muted/40" />
            ))}
          </div>
        }
      >
        <AuditLogResults eventType={eventType === "all" ? undefined : eventType} />
      </Suspense>
    </div>
  );
}
