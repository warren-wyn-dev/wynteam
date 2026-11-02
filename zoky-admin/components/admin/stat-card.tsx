import type { LucideIcon } from "lucide-react";

import { Card, CardContent, CardHeader } from "@/components/ui/card";
import { cn } from "@/lib/utils";

/**
 * Trend badge for a "_today" metric vs the same metric yesterday: the
 * ▲/▼ glyph carries the direction, colour reinforces it.
 */
function TrendBadge({ deltaPct }: { deltaPct: number | null }) {
  if (deltaPct === null) {
    return <span className="text-xs font-medium text-muted-foreground">ใหม่วันนี้</span>;
  }
  if (deltaPct === 0) {
    return <span className="text-xs font-medium text-muted-foreground">เท่ากับเมื่อวาน</span>;
  }
  const isUp = deltaPct > 0;
  // Founder 2026-11-02: green for up, red for down (the glyph still says it).
  return (
    <span className={cn("inline-flex items-center gap-0.5 text-xs font-semibold", isUp ? "text-success" : "text-destructive")}>
      {isUp ? "▲" : "▼"} {Math.abs(deltaPct).toLocaleString("th-TH")}%
      <span className="font-normal text-muted-foreground">จากเมื่อวาน</span>
    </span>
  );
}

export function StatCard({
  label,
  value,
  icon: Icon,
  sublabel,
  deltaPct,
  secondaryValue,
  secondaryLabel,
  secondaryTone = "muted",
}: {
  label: string;
  value: number;
  icon: LucideIcon;
  /** e.g. "ใน 24 ชม.ล่าสุด" -- shown under the main number. */
  sublabel?: string;
  /** vs. the same metric yesterday -- omit for metrics with no "yesterday" (e.g. rolling DAU/WAU/MAU, all-time totals). */
  deltaPct?: number | null;
  /** For the 2-number cards (Clubs, Reports) -- Design spec's Screen. */
  secondaryValue?: number;
  secondaryLabel?: string;
  /** "warn" = text-destructive (Reports' pending > 0 case). */
  secondaryTone?: "muted" | "warn";
}) {
  const ariaLabel = secondaryLabel
    ? `${label}: ${value}, ${secondaryLabel}: ${secondaryValue}`
    : `${label}: ${value}`;

  return (
    <Card aria-label={ariaLabel}>
      <CardHeader className="flex-row items-start justify-between space-y-0">
        <span className="text-sm font-medium text-muted-foreground">{label}</span>
        {/* Founder 2026-11-02: a soft ZOKY pink chip marks each metric. */}
        <span className="grid size-8 place-items-center rounded-full bg-brand-soft text-primary">
          <Icon className="size-4" aria-hidden="true" />
        </span>
      </CardHeader>
      <CardContent>
        <div className="flex items-baseline gap-3">
          <span className="text-3xl font-bold tabular-nums">{value.toLocaleString("th-TH")}</span>
          {secondaryValue !== undefined ? (
            <span
              className={cn(
                "text-lg font-semibold tabular-nums",
                secondaryTone === "warn" && secondaryValue > 0
                  ? "text-destructive"
                  : "text-muted-foreground",
              )}
            >
              {secondaryValue.toLocaleString("th-TH")}
            </span>
          ) : null}
        </div>
        {sublabel ? <p className="mt-1 text-xs text-muted-foreground">{sublabel}</p> : null}
        {secondaryLabel ? (
          <p className="text-xs text-muted-foreground">{secondaryLabel}</p>
        ) : null}
        {deltaPct !== undefined ? (
          <div className="mt-2">
            <TrendBadge deltaPct={deltaPct} />
          </div>
        ) : null}
      </CardContent>
    </Card>
  );
}
