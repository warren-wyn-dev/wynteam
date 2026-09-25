import Link from "next/link";

import { Avatar } from "@/components/phase3-ui";
import { WynosIcon } from "@/components/ui/wynos-icon";

/**
 * A deliberately quiet entry point directly under For You / Following.
 * The entire row opens the existing Beta4 composer; there is no second
 * editing surface or duplicated post/draft logic.
 */
export function HomeQuickCompose({
  avatarUrl,
  username,
}: {
  avatarUrl?: string | null;
  username?: string | null;
}) {
  return (
    <Link
      className="wyn-home-quick-compose"
      href="/?compose=1"
      aria-label="สร้างโพสต์ มีอะไรอยากแชร์?"
    >
      <span className="wyn-home-quick-compose-avatar" aria-hidden="true">
        <Avatar src={avatarUrl} label={username || "คุณ"} size={38} />
      </span>
      <span className="wyn-home-quick-compose-prompt">มีอะไรอยากแชร์?</span>
      <WynosIcon name="image" className="wyn-home-quick-compose-image" size={22} strokeWidth={1.7} />
    </Link>
  );
}
