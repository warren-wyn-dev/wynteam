import { Suspense } from "react";

import { ComposeForm } from "./compose-form";
import { AnnouncementHistory } from "./history";
import { InactiveReminderForm } from "./inactive-reminder-form";
import { InactiveReminderHistory } from "./inactive-reminder-history";
import { NoAccess } from "@/components/admin/no-access";
import { adminCan, requireAdminRole } from "@/lib/auth";

export default async function AnnouncementsPage() {
  const ctx = await requireAdminRole();
  if (!(adminCan(ctx, "social") || adminCan(ctx, "account"))) return <NoAccess what=" WYNOS Social หรือ WYNOS Account" />;
  // Both histories read the super-admin-only audit view. Keep the legacy
  // pre-foundation behavior, but never label restricted rows as empty history.
  const canViewHistory = ctx.access.superAdmin || !ctx.access.available;
  // Announcements are Social; inactive-user reminders are Account (WYN-219).
  return (
    <div className="flex flex-col gap-6 p-6">
      {adminCan(ctx, "social", "edit") ? <ComposeForm /> : null}
      <section className="flex flex-col gap-3">
        <h3 className="text-sm font-medium text-muted-foreground">ประวัติการส่งประกาศ</h3>
        {canViewHistory ? (
          <Suspense
            fallback={<div className="h-32 animate-pulse rounded-lg border bg-muted/40" />}
          >
            <AnnouncementHistory />
          </Suspense>
        ) : (
          <p className="text-sm text-muted-foreground">ประวัติการส่งประกาศดูได้เฉพาะ super admin</p>
        )}
      </section>
      {adminCan(ctx, "account", "edit") ? <InactiveReminderForm /> : null}
      <section className="flex flex-col gap-3">
        <h3 className="text-sm font-medium text-muted-foreground">ประวัติการเตือนผู้ใช้ที่ไม่ได้ใช้งาน</h3>
        {canViewHistory ? (
          <Suspense
            fallback={<div className="h-32 animate-pulse rounded-lg border bg-muted/40" />}
          >
            <InactiveReminderHistory />
          </Suspense>
        ) : (
          <p className="text-sm text-muted-foreground">ประวัติการเตือนผู้ใช้ดูได้เฉพาะ super admin</p>
        )}
      </section>
    </div>
  );
}
