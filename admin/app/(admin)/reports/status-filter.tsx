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
            (current === opt.value
              ? "bg-[#E6F9FF] text-[#0090C4]"
              : "text-muted-foreground hover:bg-accent hover:text-accent-foreground")
          }
        >
          {opt.label}
        </button>
      ))}
    </div>
  );
}
