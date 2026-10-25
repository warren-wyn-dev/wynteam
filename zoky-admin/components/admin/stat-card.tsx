import type { LucideIcon } from "lucide-react";

import { Card, CardContent, CardHeader } from "@/components/ui/card";
import { cn } from "@/lib/utils";

/**
 * Trend badge for a "_today" metric vs the same metric yesterday.
 * Deliberately grayscale-only (▲/▼ glyph + weight, no green/red hue) --
 * wyn-admin-design-system.md section 3.3 reserves color for exactly 3
 * cases (destructive action, active critical alert, primary button);
 * "growth is good" is not one of them, so direction is conveyed by the
 * glyph, not a hue.
 */
function TrendBadge({ deltaPct }: { deltaPct: number | null }) {
  if (deltaPct === null) {
    return <span className="text-xs font-medium text-muted-foreground">ใหม่วันนี้</span>;
  }
  if (deltaPct === 0) {
    return <span className="text-xs font-medium text-muted-foreground">เท่ากับเมื่อวาน</span>;
  }
  const isUp = deltaPct > 0;
  return (
    <span className="inline-flex items-center gap-0.5 text-xs font-semibold text-foreground">
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
        {/* Per wyn-admin-design-system.md section 3.3/6.7: this icon is
            decoration only, not a signal -- was `text-primary` (cyan),
            now the doc's "gray-400" neutral-scale token (zinc-400 is the
            exact hex match, see section 3.1's Zinc-based scale). */}
        <Icon className="size-4 text-zinc-400" aria-hidden="true" />
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
