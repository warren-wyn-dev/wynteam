import Link from "next/link";

import { WynosIcon, type WynosIconName } from "@/components/ui/wynos-icon";

export type BottomNavKey = "home" | "clubs" | "post" | "chat" | "profile";

export type BottomNavProps = {
  active?: Exclude<BottomNavKey, "post"> | null;
  homeHref?: string;
  clubsHref?: string;
  postHref?: string;
  chatHref?: string;
  profileHref?: string;
  className?: string;
};

type NavItem = {
  key: BottomNavKey;
  label: string;
  href: string;
  icon: WynosIconName;
};

export function BottomNav({
  active = null,
  homeHref = "/",
  clubsHref = "/clubs",
  postHref = "/?compose=1",
  chatHref = "/chat",
  profileHref = "/profile",
  className,
}: BottomNavProps) {
  const items: NavItem[] = [
    { key: "home", label: "หน้าหลัก", href: homeHref, icon: "home" },
    { key: "clubs", label: "คลับ", href: clubsHref, icon: "club" },
    { key: "post", label: "โพสต์", href: postHref, icon: "post" },
    { key: "chat", label: "แชท", href: chatHref, icon: "chat" },
    { key: "profile", label: "โปรไฟล์", href: profileHref, icon: "profile" },
  ];

  return (
    <nav className={["wyn-bottom-nav", className ?? ""].filter(Boolean).join(" ")} aria-label="เมนูหลัก">
      {items.map((item) => {
        const isPost = item.key === "post";
        const isActive = !isPost && active === item.key;

        return (
          <Link
            aria-current={isActive ? "page" : undefined}
            aria-label={isPost ? "สร้างโพสต์ใหม่" : item.label}
            className={`wyn-bottom-nav__link${isPost ? " wyn-bottom-nav__post" : ""}`}
            href={item.href}
            key={item.key}
          >
            {isPost ? (
              <span className="wyn-bottom-nav__post-icon" aria-hidden="true">
                <WynosIcon name="post" size={24} strokeWidth={2} />
              </span>
            ) : (
              <WynosIcon name={item.icon} size={22} />
            )}
            <span className="wyn-bottom-nav__label">{item.label}</span>
          </Link>
        );
      })}
    </nav>
  );
}
