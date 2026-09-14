import { Bookmark, ChevronRight, Compass, Smartphone, UsersRound, X } from "lucide-react";
import { useRouter } from "next/navigation";

import { Avatar } from "@/components/phase3-ui";
import type { HomeIdentity } from "@/lib/home-parity-data";

/** Home's side menu (Flutter's SideMenu Drawer). Shares its
 * `.home-drawer`/`.drawer-*` classes with the Notifications route's own
 * drawer — a generic app-chrome pattern, not Home-specific styling. */
export function HomeDrawer({ identity, onClose }: { identity: HomeIdentity | null; onClose: () => void }) {
  const router = useRouter();
  const go = (href: string) => {
    onClose();
    router.push(href);
  };
  const displayName = identity?.display_name?.trim() || identity?.username || "WYNOS";
  const standalone =
    typeof window !== "undefined" &&
    (window.matchMedia("(display-mode: standalone)").matches ||
      Boolean((window.navigator as Navigator & { standalone?: boolean }).standalone));

  return (
    <div className="home-drawer-backdrop" role="presentation" onClick={onClose}>
      <aside
        className="home-drawer"
        role="dialog"
        aria-modal="true"
        aria-label="เมนู WYNOS"
        onClick={(event) => event.stopPropagation()}
      >
        <div className="home-drawer-close">
          <button className="icon-button" type="button" aria-label="ปิด" onClick={onClose}>
            <X size={22} />
          </button>
        </div>
        <button
          className="drawer-identity"
          type="button"
          disabled={!identity}
          onClick={() => identity && go(`/profile/${identity.id}`)}
        >
          <Avatar src={identity?.avatar_url} label={identity?.username || "W"} size={56} />
          <span className="drawer-identity-copy">
            <strong>{displayName}</strong>
            {identity ? <small>@{identity.username}</small> : null}
            <span>
              <b>{identity?.follower_count ?? 0}</b> ผู้ติดตาม · <b>{identity?.following_count ?? 0}</b>{" "}
              กำลังติดตาม
            </span>
          </span>
          <ChevronRight size={20} />
        </button>
        <div className="drawer-divider" />
        <div className="drawer-menu-list">
          <button className="drawer-menu-row" type="button" onClick={() => go("/clubs")}>
            <span className="drawer-menu-icon"><Compass size={19} /></span>
            <span>สำรวจ Club</span>
            <ChevronRight size={19} />
          </button>
          <button className="drawer-menu-row" type="button" onClick={() => go("/clubs/new")}>
            <span className="drawer-menu-icon"><span className="drawer-plus">＋</span></span>
            <span>สร้าง Club</span>
            <ChevronRight size={19} />
          </button>
          <button className="drawer-menu-row" type="button" onClick={() => go("/clubs?mine=1")}>
            <span className="drawer-menu-icon"><UsersRound size={19} /></span>
            <span>Club ของฉัน</span>
            <ChevronRight size={19} />
          </button>
          <button className="drawer-menu-row" type="button" onClick={() => go("/bookmarks")}>
            <span className="drawer-menu-icon"><Bookmark size={19} /></span>
            <span>บันทึกไว้</span>
            <ChevronRight size={19} />
          </button>
          {!standalone ? (
            <button
              className="drawer-menu-row"
              type="button"
              onClick={() => window.open("/add-to-home.html", "_blank", "noopener,noreferrer")}
            >
              <span className="drawer-menu-icon"><Smartphone size={19} /></span>
              <span>เพิ่ม WYNOS ไว้ที่หน้าจอหลัก</span>
              <ChevronRight size={19} />
            </button>
          ) : null}
        </div>
      </aside>
    </div>
  );
}
