import Link from "next/link";

import { WynosIcon } from "@/components/ui/wynos-icon";

/**
 * WYN-195: WYNOS Food entry under the Home tabs. Home renders it only for
 * developer accounts while Food is in its developer rollout; /food keeps its
 * own server-side gate.
 */
export function HomeFoodShortcut() {
  return (
    <Link className="wyn-home-food-shortcut" href="/food" aria-label="เปิด WYNOS Food สั่งอาหาร">
      <span className="wyn-home-food-shortcut-icon" aria-hidden="true">
        <WynosIcon name="food" size={20} strokeWidth={1.9} />
      </span>
      <span className="wyn-home-food-shortcut-copy">
        <strong>WYNOS Food</strong>
        <small>สั่งอาหาร ส่งถึงที่</small>
      </span>
      <WynosIcon name="chevronRight" className="wyn-home-food-shortcut-chevron" size={20} strokeWidth={1.9} />
    </Link>
  );
}
