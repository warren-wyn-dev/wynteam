import Link from "next/link";
import { ChevronRight, UtensilsCrossed } from "lucide-react";

/** Developer-only shortcut. Authorization is checked again at /food. */
export function WynosFoodEntry() {
  return (
    <div className="wyn-food-entry-wrap">
      <Link className="wyn-food-entry" href="/food" aria-label="WYNOS Food — หน้าทดลองสำหรับนักพัฒนา">
        <span className="wyn-food-entry-icon" aria-hidden="true">
          <UtensilsCrossed size={22} strokeWidth={2} />
        </span>
        <span className="wyn-food-entry-copy">
          <span className="wyn-food-entry-heading">
            <strong>WYNOS Food</strong>
            <span className="wyn-food-entry-badge">กำลังพัฒนา</span>
          </span>
          <span className="wyn-food-entry-description">บริการสั่งอาหารของ WYNOS</span>
        </span>
        <ChevronRight className="wyn-food-entry-chevron" size={20} strokeWidth={2} aria-hidden="true" />
      </Link>
    </div>
  );
}
