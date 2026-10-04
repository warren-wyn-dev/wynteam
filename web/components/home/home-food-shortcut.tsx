import Link from "next/link";

import { WynosIcon } from "@/components/ui/wynos-icon";

/**
 * WYNOS Food entry under the Home tabs (WYN-195). Since WYN-212 Home shows
 * it only to people known to be in Maha Sarakham, and they can hide it;
 * everyone still finds Food in the drawer.
 */
export function HomeFoodShortcut({ onHide }: { onHide: () => void }) {
  return (
    <div className="wyn-home-food-shortcut">
      <Link className="wyn-home-food-shortcut-link" href="/food" aria-label="เปิด WYNOS Food สั่งอาหาร">
        <span className="wyn-home-food-shortcut-icon" aria-hidden="true">
          <WynosIcon name="food" size={20} strokeWidth={1.9} />
        </span>
        <span className="wyn-home-food-shortcut-copy">
          <strong>WYNOS Food</strong>
          <small>สั่งอาหาร ส่งถึงที่</small>
        </span>
        <WynosIcon name="chevronRight" className="wyn-home-food-shortcut-chevron" size={20} strokeWidth={1.9} />
      </Link>
      <button className="wyn-home-food-shortcut-close" type="button" aria-label="ซ่อน WYNOS Food จากหน้าหลัก" onClick={onHide}>
        <WynosIcon name="close" size={18} strokeWidth={1.9} />
      </button>
    </div>
  );
}
