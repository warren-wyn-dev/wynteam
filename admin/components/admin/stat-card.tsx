import type { LucideIcon } from "lucide-react";

import { Card, CardContent, CardHeader } from "@/components/ui/card";
import { cn } from "@/lib/utils";

export function StatCard({
  label,
  value,
  icon: Icon,
  sublabel,
  secondaryValue,
  secondaryLabel,
  secondaryTone = "muted",
}: {
  label: string;
  value: number;
  icon: LucideIcon;
  /** e.g. "ใน 24 ชม.ล่าสุด" -- shown under the main number. */
  sublabel?: string;
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
        <Icon className="size-4 text-primary" aria-hidden="true" />
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
      </CardContent>
    </Card>
  );
}
