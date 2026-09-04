import { Card, CardContent, CardHeader } from "@/components/ui/card";
import type { DauDay } from "@/lib/admin-metrics";

/**
 * The Dashboard's one headline chart -- per the Founder's ask for
 * "easier to see the trend, not just today's number." DAU (not new
 * signups or drops) is the pulse metric every other section already
 * treats as the primary rolling-activity signal (see
 * admin_dashboard_metrics()'s own DAU/WAU/MAU comment), so it's the one
 * metric worth a full 14-day line rather than a single vs-yesterday
 * badge.
 *
 * Server-rendered SVG, no chart library -- 14 points is simple enough
 * that pulling in a dependency for it would cost more than it saves.
 * Colors read from the page's own CSS tokens via currentColor /
 * Tailwind text-* classes so this holds up in both themes automatically
 * (wyn-admin-design-system.md section 8).
 */
export function DauTrendChart({ days }: { days: DauDay[] }) {
  const width = 640;
  const height = 160;
  const padX = 8;
  const padTop = 16;
  const padBottom = 28;

  const counts = days.map((d) => d.count);
  const max = Math.max(...counts, 1);
  const min = 0; // counts are never negative -- baseline the chart at 0, not the week's min, so the line's height means something absolute.

  const plotWidth = width - padX * 2;
  const plotHeight = height - padTop - padBottom;

  const points = days.map((d, i) => {
    const x = padX + (i / Math.max(days.length - 1, 1)) * plotWidth;
    const y = padTop + plotHeight - ((d.count - min) / (max - min || 1)) * plotHeight;
    return { x, y, ...d };
  });

  const linePath = points.map((p, i) => `${i === 0 ? "M" : "L"} ${p.x.toFixed(1)} ${p.y.toFixed(1)}`).join(" ");
  const areaPath = `${linePath} L ${points[points.length - 1].x.toFixed(1)} ${(padTop + plotHeight).toFixed(1)} L ${points[0].x.toFixed(1)} ${(padTop + plotHeight).toFixed(1)} Z`;

  const first = points[0];
  const last = points[points.length - 1];
  const avg = Math.round(counts.reduce((a, b) => a + b, 0) / (counts.length || 1));

  const formatDay = (iso: string) =>
    new Date(iso).toLocaleDateString("th-TH", { day: "numeric", month: "short" });

  return (
    <Card>
      <CardHeader className="flex-row items-start justify-between space-y-0">
        <div className="flex flex-col gap-0.5">
          <span className="text-sm font-medium text-muted-foreground">
            ผู้ใช้งานที่ Active ต่อวัน (DAU) — 14 วันล่าสุด
          </span>
          <span className="text-xs text-muted-foreground">
            เฉลี่ย {avg.toLocaleString("th-TH")} คน/วัน
          </span>
        </div>
      </CardHeader>
      <CardContent>
        <svg
          viewBox={`0 0 ${width} ${height}`}
          className="w-full text-foreground"
          role="img"
          aria-label={`กราฟผู้ใช้งาน Active ต่อวัน 14 วันล่าสุด ตั้งแต่ ${formatDay(first.date)} ถึง ${formatDay(last.date)}, เฉลี่ย ${avg} คนต่อวัน`}
        >
          <path d={areaPath} className="fill-muted" />
          <path d={linePath} fill="none" stroke="currentColor" strokeWidth={2} strokeLinejoin="round" strokeLinecap="round" />
          <circle cx={last.x} cy={last.y} r={4} fill="currentColor" />

          <text x={first.x} y={height - 6} fontSize={11} textAnchor="start" className="fill-muted-foreground">
            {formatDay(first.date)}
          </text>
          <text x={last.x} y={height - 6} fontSize={11} textAnchor="end" className="fill-muted-foreground">
            {formatDay(last.date)}
          </text>
          <text x={padX} y={padTop} fontSize={11} textAnchor="start" className="fill-muted-foreground">
            {max.toLocaleString("th-TH")}
          </text>
        </svg>
      </CardContent>
    </Card>
  );
}
