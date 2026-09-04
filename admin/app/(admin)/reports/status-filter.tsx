"use client";

import { useRouter, useSearchParams } from "next/navigation";

const OPTIONS: { value: string; label: string }[] = [
  { value: "open", label: "รอดำเนินการ" },
  { value: "actioned", label: "ดำเนินการแล้ว" },
  { value: "dismissed", label: "ยกเลิกแล้ว" },
  { value: "all", label: "ทั้งหมด" },
];

export function StatusFilter() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const current = searchParams.get("status") ?? "open";

  return (
    <div className="flex gap-2">
      {OPTIONS.map((opt) => (
        <button
          key={opt.value}
          type="button"
          onClick={() => router.push(`/reports?status=${opt.value}`)}
          className={
            "rounded-md px-3 py-1.5 text-sm font-medium transition-colors " +
            // Per wyn-admin-design-system.md section 3.3: no color accent
            // for a plain filter toggle (was leftover cyan). `bg-muted`/
            // `text-foreground` match the doc's neutral "active" treatment
            // used elsewhere (see components/admin/sidebar.tsx).
            (current === opt.value
              ? "bg-muted font-semibold text-foreground"
              : "text-muted-foreground hover:bg-accent hover:text-accent-foreground")
          }
        >
          {opt.label}
        </button>
      ))}
    </div>
  );
}
