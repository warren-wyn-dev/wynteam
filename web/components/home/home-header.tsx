/* eslint-disable @next/next/no-img-element */
import { Bell, Menu, Search } from "lucide-react";

import { WynosHeader } from "@/components/design-system/WynosHeader";
import { WynosIconButton } from "@/components/design-system/WynosIconButton";

/**
 * Home's header (WYN-159 design system, `WynosHeader` — `.header-row` in the
 * reference: leading icon button, centered brand, trailing actions).
 *
 * CORRECTED 2026-09-14: Founder reviewed a direct side-by-side screenshot
 * comparison against `wynos-home-v2.html` and confirmed matching it 100%
 * exactly (see `.wyn/company/DECISIONS.md`). This supersedes the earlier
 * decision recorded here to keep a single Chat-icon-with-badge trailing
 * action — the trailing actions are now Search + Bell/Notifications
 * (carrying the unread-notification badge that used to live on the bottom
 * nav's now-removed Notifications slot), matching the reference exactly.
 * Chat is no longer surfaced in the header — it is now a global bottom-nav
 * destination (see `components/bottom-navigation.tsx`). The brand wordmark
 * reads "Wynos" (capital W only), matching the reference literally — this
 * correction is scoped to this one Home-header element, not a global
 * "WYNOS" rebrand.
 */
export function HomeHeader({
  notificationBadge,
  notificationLabel,
  onOpenMenu,
  onOpenSearch,
  onOpenNotifications,
}: {
  notificationBadge: string | null;
  notificationLabel: string;
  onOpenMenu: () => void;
  onOpenSearch: () => void;
  onOpenNotifications: () => void;
}) {
  return (
    <WynosHeader
      leading={<WynosIconButton icon={<Menu />} aria-label="เมนู" onClick={onOpenMenu} />}
      center={
        <>
          <img src="/wynos_logo_mark.png" alt="" width={22} height={22} />
          <strong>Wynos</strong>
        </>
      }
      trailing={
        <>
          <WynosIconButton icon={<Search />} aria-label="ค้นหา" onClick={onOpenSearch} />
          <WynosIconButton
            icon={<Bell />}
            aria-label={notificationLabel}
            onClick={onOpenNotifications}
            badge={notificationBadge}
          />
        </>
      }
    />
  );
}
