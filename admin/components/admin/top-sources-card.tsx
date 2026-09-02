import { Card, CardContent, CardHeader } from "@/components/ui/card";
import type { TopSource } from "@/lib/admin-metrics";

/**
 * WYN-077's one new component -- everything else in the Growth section
 * reuses StatCard as-is. Not a StatCard variant on purpose: this is a
 * ranked list, not a single number, so it gets its own small layout
 * instead of being forced into StatCard's shape. See
 * .wyn/docs/design/wyn-077-basic-product-analytics.md.
 */
export function TopSourcesCard({ sources }: { sources: TopSource[] }) {
  return (
    <Card className="lg:col-span-2">
      <CardHeader>
        <span className="text-sm font-medium text-muted-foreground">
          ช่องทางยอดนิยม (7 วันล่าสุด)
        </span>
      </CardHeader>
      <CardContent>
        {sources.length === 0 ? (
          <p className="py-2 text-sm text-muted-foreground">ยังไม่มีข้อมูลช่องทาง</p>
        ) : (
          <ul className="flex flex-col gap-2">
            {sources.map((s) => (
              <li key={s.source} className="flex items-center justify-between text-sm">
                <span>{s.source}</span>
                <span className="tabular-nums text-muted-foreground">
                  {s.count.toLocaleString("th-TH")}
                </span>
              </li>
            ))}
          </ul>
        )}
      </CardContent>
    </Card>
  );
}
