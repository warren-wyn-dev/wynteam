import { Suspense } from "react";

import { ComposeForm } from "./compose-form";
import { AnnouncementHistory } from "./history";

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
    </div>
  );
}
