import { Suspense } from "react";

import { StatusFilter } from "./status-filter";
import { QueueResults } from "./results";

export default async function ReportsPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string }>;
}) {
  const { status } = await searchParams;
  const resolvedStatus = status ?? "open";

  return (
    <div className="flex flex-col gap-4 p-6">
      <StatusFilter />
      <Suspense
        key={resolvedStatus}
        fallback={
          <div className="flex flex-col gap-2">
            {Array.from({ length: 5 }).map((_, i) => (
              <div key={i} className="h-14 animate-pulse rounded-lg border bg-muted/40" />
            ))}
          </div>
        }
      >
        <QueueResults status={resolvedStatus} />
      </Suspense>
    </div>
  );
}
