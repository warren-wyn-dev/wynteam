/**
 * Same 4-section/12-card shape as the real grid (DashboardMetrics) --
 * Design spec: "ตำแหน่งเดียวกับ layout จริงเป๊ะ (กัน layout shift ตอนโหลดเสร็จ)".
 */
const SECTIONS = [
  { title: "ผู้ใช้งาน", count: 4 },
  { title: "เนื้อหา", count: 3 },
  { title: "การมีส่วนร่วม", count: 4 },
  { title: "รายงาน", count: 1 },
];

export function DashboardSkeleton() {
  return (
    <div className="flex flex-col gap-6 p-6">
      {SECTIONS.map((section) => (
        <div key={section.title} className="flex flex-col gap-3">
          <div className="h-5 w-24 animate-pulse rounded bg-muted" />
          <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-4">
            {Array.from({ length: section.count }).map((_, i) => (
              <div key={i} className="h-28 animate-pulse rounded-xl border bg-muted/40" />
            ))}
          </div>
        </div>
      ))}
    </div>
  );
}
