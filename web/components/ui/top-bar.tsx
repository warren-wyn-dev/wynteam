import type { ReactNode } from "react";
import Link from "next/link";

import { WynosIcon } from "@/components/ui/wynos-icon";

export type TopBarProps = {
  title: string;
  backHref?: string;
  backLabel?: string;
  right?: ReactNode;
  className?: string;
};

export function TopBar({
  title,
  backHref,
  backLabel = "ย้อนกลับ",
  right,
  className,
}: TopBarProps) {
  return (
    <header className={["wyn-top-bar", className ?? ""].filter(Boolean).join(" ")}>
      {backHref ? (
        <Link aria-label={backLabel} className="wyn-icon-button" href={backHref}>
          <WynosIcon name="back" size={22} />
        </Link>
      ) : (
        <span aria-hidden="true" />
      )}

      <h1 className="wyn-top-bar__title">{title}</h1>
      <div className="wyn-top-bar__right">{right}</div>
    </header>
  );
}
