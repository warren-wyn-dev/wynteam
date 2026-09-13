"use client";

import { useRouter } from "next/navigation";
import { useEffect } from "react";

const destinations: Record<string, string> = {
  "สำรวจ Club": "/clubs",
  "สร้าง Club": "/clubs/new",
  "Club ของฉัน": "/clubs?mine=1",
  "บันทึกไว้": "/bookmarks",
};

/**
 * Keeps the Founder-approved Side Menu labels wired to their real Next.js
 * destinations while the Home drawer remains embedded in the parity Home
 * component. Capture phase prevents an older staged href from winning first.
 */
export function DrawerRouteAdapter() {
  const router = useRouter();

  useEffect(() => {
    const onClick = (event: MouseEvent) => {
      const target = event.target;
      if (!(target instanceof Element)) return;
      const row = target.closest<HTMLButtonElement>("button.drawer-menu-row");
      if (!row) return;
      const label = row.textContent?.replace(/\s+/g, " ").trim() ?? "";
      const match = Object.keys(destinations).find((name) => label.includes(name));
      if (!match) return;
      event.preventDefault();
      event.stopPropagation();
      router.push(destinations[match]);
    };

    document.addEventListener("click", onClick, true);
    return () => document.removeEventListener("click", onClick, true);
  }, [router]);

  return null;
}
