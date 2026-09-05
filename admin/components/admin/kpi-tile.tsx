import type { LucideIcon } from "lucide-react";
import Link from "next/link";

import { TrendBadge } from "@/components/admin/stat-card";
import { Card, CardContent, CardHeader } from "@/components/ui/card";
import { cn } from "@/lib/utils";

/**
 * Section 1's "ภาพรวมวันนี้" overview ribbon (Admin Dashboard restructure
 * spec) -- the 4 things the spec says must be visible "within a few
 * seconds" of opening the page, so this is deliberately its own,
 * slightly punchier component rather than reusing StatCard as-is:
 * clickable (every Section 1 tile links to its own detail page, per
 * the spec) and able to carry a traffic-light [status] dot, which
 * StatCard's plain secondaryTone="warn" can't express (only 2 states,
 * not 3).
 *
 * The traffic light is a deliberate, narrow exception to
 * wyn-admin-design-system.md section 3.3's "color only for destructive/
 * active-alert/primary-button" rule -- the Founder's own restructure
 * spec specifies exactly this green/yellow/red status for the one
 * "ต้องดำเนินการ" tile ("0 = ปกติ, 1-5 = ต้องตรวจสอบ, มากกว่า 5 =
 * ต้องดำเนินการ"), which is itself an active-alert-severity signal, not
 * a "more is good" judgement applied to an ordinary metric. Every other
 * tile here (and every StatCard elsewhere) stays grayscale.
 */
export function KpiTile({
  label,
  value,
  icon: Icon,
  sublabel,
  deltaPct,
  href,
  status,
}: {
  label: string;
  value: number;
  icon: LucideIcon;
  sublabel?: string;
  /** vs. the same metric yesterday, matched to the same elapsed time -- omit if not applicable. */
  deltaPct?: number | null;
  /** Where this tile's own detail page lives. */
  href?: string;
  status?: { level: "ok" | "watch" | "urgent"; label: string };
}) {
  const card = (
    <Card className={cn(href && "transition-colors hover:bg-accent/50")}>
      <CardHeader className="flex-row items-start justify-between space-y-0">
        <span className="text-sm font-medium text-muted-foreground">{label}</span>
        <Icon className="size-4 text-zinc-400" aria-hidden="true" />
      </CardHeader>
      <CardContent>
        <div className="flex items-center gap-2">
          <span className="text-3xl font-bold tabular-nums">{value.toLocaleString("th-TH")}</span>
          {status ? (
            <span
              className={cn(
                "size-2.5 shrink-0 rounded-full",
                status.level === "ok" && "bg-emerald-500",
                status.level === "watch" && "bg-amber-500",
                status.level === "urgent" && "bg-destructive",
              )}
              aria-hidden="true"
            />
          ) : null}
        </div>
        {sublabel ? <p className="mt-1 text-xs text-muted-foreground">{sublabel}</p> : null}
        {status ? (
          <p
            className={cn(
              "mt-1 text-xs font-medium",
              status.level === "ok" && "text-muted-foreground",
              status.level === "watch" && "text-amber-600",
              status.level === "urgent" && "text-destructive",
            )}
          >
            {status.label}
          </p>
        ) : null}
        {deltaPct !== undefined ? (
          <div className="mt-2">
            <TrendBadge deltaPct={deltaPct} />
          </div>
        ) : null}
      </CardContent>
    </Card>
  );

  if (!href) return card;

  return (
    <Link href={href} aria-label={`${label}: ${value.toLocaleString("th-TH")}`} className="block">
      {card}
    </Link>
  );
}
