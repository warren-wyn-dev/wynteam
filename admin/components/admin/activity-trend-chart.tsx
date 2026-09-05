"use client";

import { useState } from "react";

import { Card, CardContent, CardHeader } from "@/components/ui/card";
import type { ActivityTrendDay } from "@/lib/admin-metrics";

const RANGE_OPTIONS = [7, 30, 90] as const;
type Range = (typeof RANGE_OPTIONS)[number];

/**
 * Admin Dashboard restructure spec, Sections 2 & 4: both "Active Users
 * Trend" and "Engagement Trend" are the same shape (one line, a
 * 7/30/90-day pill selector) over the same admin_activity_trend() data
 * -- one component, told which of its two series to draw, rather than
 * near-duplicate chart components for each.
 *
 * [days] always carries the full 90-day fetch (see
 * fetchAdminActivityTrend in admin-metrics.ts) -- switching range here
 * slices that array client-side, never a new request, so the pill
 * selector needs "use client" for its own state but nothing else on
 * this page does.
 *
 * Server-rendered-shape SVG (no chart library, same reasoning as the
 * DAU chart this replaces), just running client-side now that the
 * range is interactive. Colors read from the page's own CSS tokens via
 * currentColor/Tailwind text-* classes so this holds up in both themes
 * automatically (wyn-admin-design-system.md section 8).
 */
export function ActivityTrendChart({
  title,
  unitLabel,
  days,
  series,
  defaultRange = 30,
}: {
  title: string;
  /** e.g. "คน/วัน" or "ครั้ง/วัน" -- shown next to the average. */
  unitLabel: string;
  days: ActivityTrendDay[];
  series: "active_users" | "engagement";
  defaultRange?: Range;
}) {
  const [range, setRange] = useState<Range>(defaultRange);
  const sliced = days.slice(-range);

  const width = 640;
  const height = 160;
  const padX = 8;
  const padTop = 16;
  const padBottom = 28;

  const values = sliced.map((d) => d[series]);
  const max = Math.max(...values, 1);
  const min = 0; // counts are never negative -- baseline at 0, not the range's own min, so the line's height means something absolute.

  const plotWidth = width - padX * 2;
  const plotHeight = height - padTop - padBottom;

  const points = sliced.map((d, i) => {
    const x = padX + (i / Math.max(sliced.length - 1, 1)) * plotWidth;
    const y = padTop + plotHeight - ((d[series] - min) / (max - min || 1)) * plotHeight;
    return { x, y, ...d };
  });

  const formatDay = (iso: string) =>
    new Date(iso).toLocaleDateString("th-TH", { day: "numeric", month: "short" });

  if (points.length === 0) {
    return null;
  }

  const linePath = points.map((p, i) => `${i === 0 ? "M" : "L"} ${p.x.toFixed(1)} ${p.y.toFixed(1)}`).join(" ");
  const areaPath = `${linePath} L ${points[points.length - 1].x.toFixed(1)} ${(padTop + plotHeight).toFixed(1)} L ${points[0].x.toFixed(1)} ${(padTop + plotHeight).toFixed(1)} Z`;

  const first = points[0];
  const last = points[points.length - 1];
  const avg = Math.round(values.reduce((a, b) => a + b, 0) / (values.length || 1));

  return (
    <Card>
      <CardHeader className="flex-row items-start justify-between space-y-0">
        <div className="flex flex-col gap-0.5">
          <span className="text-sm font-medium text-muted-foreground">{title}</span>
          <span className="text-xs text-muted-foreground">
            เฉลี่ย {avg.toLocaleString("th-TH")} {unitLabel}
          </span>
        </div>
        <div className="flex gap-1">
          {RANGE_OPTIONS.map((r) => (
            <button
              key={r}
              type="button"
              onClick={() => setRange(r)}
              className={
                "rounded-md px-2 py-1 text-xs font-medium transition-colors " +
                (range === r
                  ? "bg-muted font-semibold text-foreground"
                  : "text-muted-foreground hover:bg-accent hover:text-accent-foreground")
              }
            >
              {r} วัน
            </button>
          ))}
        </div>
      </CardHeader>
      <CardContent>
        <svg
          viewBox={`0 0 ${width} ${height}`}
          className="w-full text-foreground"
          role="img"
          aria-label={`${title} ${range} วันล่าสุด ตั้งแต่ ${formatDay(first.day)} ถึง ${formatDay(last.day)}, เฉลี่ย ${avg} ${unitLabel}`}
        >
          <path d={areaPath} className="fill-muted" />
          <path d={linePath} fill="none" stroke="currentColor" strokeWidth={2} strokeLinejoin="round" strokeLinecap="round" />
          <circle cx={last.x} cy={last.y} r={4} fill="currentColor" />

          <text x={first.x} y={height - 6} fontSize={11} textAnchor="start" className="fill-muted-foreground">
            {formatDay(first.day)}
          </text>
          <text x={last.x} y={height - 6} fontSize={11} textAnchor="end" className="fill-muted-foreground">
            {formatDay(last.day)}
          </text>
          <text x={padX} y={padTop} fontSize={11} textAnchor="start" className="fill-muted-foreground">
            {max.toLocaleString("th-TH")}
          </text>
        </svg>
      </CardContent>
    </Card>
  );
}
