import { Suspense } from "react";

import { ComposeForm } from "./compose-form";
import { AnnouncementHistory } from "./history";
import { InactiveReminderForm } from "./inactive-reminder-form";
import { InactiveReminderHistory } from "./inactive-reminder-history";

export default function AnnouncementsPage() {
  return (
    <div className="flex flex-col gap-6 p-6">
      <ComposeForm />
      <section className="flex flex-col gap-3">
        <h3 className="text-sm font-medium text-muted-foreground">ประวัติการส่งประกาศ</h3>
        <Suspense
          fallback={<div className="h-32 animate-pulse rounded-lg border bg-muted/40" />}
        >
          <AnnouncementHistory />
        </Suspense>
      </section>
      <InactiveReminderForm />
      <section className="flex flex-col gap-3">
        <h3 className="text-sm font-medium text-muted-foreground">ประวัติการเตือนผู้ใช้ที่ไม่ได้ใช้งาน</h3>
        <Suspense
          fallback={<div className="h-32 animate-pulse rounded-lg border bg-muted/40" />}
        >
          <InactiveReminderHistory />
        </Suspense>
      </section>
    </div>
  );
}
