import { motion } from "framer-motion";
import { useRouter } from "next/navigation";

import { Avatar } from "@/components/phase3-ui";
import { WynosIcon } from "@/components/ui/wynos-icon";
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
    <motion.div
      className="home-drawer-backdrop"
      role="presentation"
      onClick={onClose}
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      transition={{ duration: 0.18 }}
    >
      <motion.aside
        className="home-drawer"
        role="dialog"
        aria-modal="true"
        aria-label="เมนู WYNOS"
        onClick={(event) => event.stopPropagation()}
        initial={{ x: "-100%" }}
        animate={{ x: 0 }}
        exit={{ x: "-100%" }}
        transition={{ duration: 0.22, ease: "easeOut" }}
      >
        <div className="home-drawer-close">
          <button className="icon-button" type="button" aria-label="ปิด" onClick={onClose}>
            <WynosIcon name="close" size={22} strokeWidth={2} />
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
          <WynosIcon name="chevronRight" size={20} strokeWidth={2} />
        </button>
        <div className="drawer-divider" />
        <div className="drawer-menu-list">
          <button className="drawer-menu-row" type="button" onClick={() => go("/clubs")}>
            <span className="drawer-menu-icon"><WynosIcon name="compass" size={19} strokeWidth={2} /></span>
            <span>สำรวจ Club</span>
            <WynosIcon name="chevronRight" size={19} strokeWidth={2} />
          </button>
          <button className="drawer-menu-row" type="button" onClick={() => go("/clubs/new")}>
            <span className="drawer-menu-icon"><span className="drawer-plus">＋</span></span>
            <span>สร้าง Club</span>
            <WynosIcon name="chevronRight" size={19} strokeWidth={2} />
          </button>
          <button className="drawer-menu-row" type="button" onClick={() => go("/clubs?mine=1")}>
            <span className="drawer-menu-icon"><WynosIcon name="club" size={19} strokeWidth={2} /></span>
            <span>Club ของฉัน</span>
            <WynosIcon name="chevronRight" size={19} strokeWidth={2} />
          </button>
          <button className="drawer-menu-row" type="button" onClick={() => go("/bookmarks")}>
            <span className="drawer-menu-icon"><WynosIcon name="bookmark" size={19} strokeWidth={2} /></span>
            <span>บันทึกไว้</span>
            <WynosIcon name="chevronRight" size={19} strokeWidth={2} />
          </button>
          <button className="drawer-menu-row" type="button" onClick={() => go("/drafts")}>
            <span className="drawer-menu-icon"><WynosIcon name="fileText" size={19} strokeWidth={2} /></span>
            <span>ร่าง</span>
            <WynosIcon name="chevronRight" size={19} strokeWidth={2} />
          </button>
          {!standalone ? (
            <button
              className="drawer-menu-row"
              type="button"
              onClick={() => window.open("/add-to-home.html", "_blank", "noopener,noreferrer")}
            >
              <span className="drawer-menu-icon"><WynosIcon name="smartphone" size={19} strokeWidth={2} /></span>
              <span>เพิ่ม WYNOS ไว้ที่หน้าจอหลัก</span>
              <WynosIcon name="chevronRight" size={19} strokeWidth={2} />
            </button>
          ) : null}
        </div>
      </motion.aside>
    </motion.div>
  );
}
