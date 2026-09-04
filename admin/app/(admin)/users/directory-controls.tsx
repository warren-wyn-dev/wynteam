"use client";

import { useRouter, useSearchParams } from "next/navigation";

/**
 * Three independent pill rows (sort / role / status), each its own URL
 * search param -- same pattern as reports/status-filter.tsx (plain
 * pills + router.push, no client state), so all three combine freely
 * and the page stays a normal server-rendered link, shareable/
 * bookmarkable like every other filtered view in this app.
 */
function PillRow({
  param,
  options,
  defaultValue,
}: {
  param: string;
  options: { value: string; label: string }[];
  defaultValue: string;
}) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const current = searchParams.get(param) ?? defaultValue;

  function select(value: string) {
    const next = new URLSearchParams(searchParams.toString());
    if (value === defaultValue) {
      next.delete(param);
    } else {
      next.set(param, value);
    }
    router.push(`/users?${next.toString()}`);
  }

  return (
    <div className="flex flex-wrap gap-2">
      {options.map((opt) => (
        <button
          key={opt.value}
          type="button"
          onClick={() => select(opt.value)}
          className={
            "rounded-md px-3 py-1.5 text-sm font-medium transition-colors " +
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

const SORT_OPTIONS = [
  { value: "newest", label: "สมัครล่าสุด" },
  { value: "most_active", label: "แอคทีฟที่สุด" },
  { value: "dormant", label: "หายไปนานสุด" },
  { value: "oldest", label: "สมัครก่อน" },
];

const ROLE_OPTIONS = [
  { value: "all", label: "ทุกสิทธิ์" },
  { value: "admin", label: "Admin" },
  { value: "moderator", label: "Moderator" },
  { value: "user", label: "User" },
];

const STATUS_OPTIONS = [
  { value: "all", label: "ทุกสถานะ" },
  { value: "normal", label: "ปกติ" },
  { value: "restrict", label: "ถูกจำกัด" },
  { value: "suspend", label: "ถูกระงับ" },
  { value: "ban", label: "ถูกแบน" },
];

export function DirectorySortPills() {
  return <PillRow param="sort" options={SORT_OPTIONS} defaultValue="newest" />;
}

export function DirectoryRolePills() {
  return <PillRow param="role" options={ROLE_OPTIONS} defaultValue="all" />;
}

export function DirectoryStatusPills() {
  return <PillRow param="status" options={STATUS_OPTIONS} defaultValue="all" />;
}
