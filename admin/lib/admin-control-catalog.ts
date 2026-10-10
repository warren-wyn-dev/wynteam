import type { AdminRole } from "@/lib/auth";

/**
 * Phase-1 inventory only. A navigable route is not proof that every backend
 * operation behind it is fully implemented or integration-tested.
 *
 * This registry MUST NOT grant permissions; server pages/RPC/RLS own access.
 * Planned capabilities intentionally have no href and no write handlers.
 */
export type AdminControlCapability = {
  id: string;
  label: string;
  stage: "existing-route" | "planned";
  href?: string;
  roles?: readonly AdminRole[];
  note?: string;
};

export type AdminControlArea = {
  id: string;
  title: string;
  subtitle: string;
  capabilities: readonly AdminControlCapability[];
};

export const ADMIN_CONTROL_AREAS: readonly AdminControlArea[] = [
  {
    id: "social",
    title: "WYNOS Social",
    subtitle: "wynos.online · ผู้ใช้ เนื้อหา และชุมชน",
    capabilities: [
      { id: "social-dashboard", label: "แดชบอร์ดและตัวชี้วัด Social", stage: "existing-route", href: "/social" },
      { id: "users", label: "ค้นหาและจัดการผู้ใช้", stage: "existing-route", href: "/users" },
      { id: "moderation", label: "ตรวจสอบและจัดการเนื้อหา", stage: "existing-route", href: "/moderation" },
      { id: "reports", label: "ตรวจสอบรายงานการละเมิด", stage: "existing-route", href: "/reports" },
      { id: "announcements", label: "ประกาศอย่างเป็นทางการ", stage: "existing-route", href: "/announcements" },
      { id: "clubs", label: "กำกับดูแลคลับและบทสนทนาแบบครบวงจร", stage: "planned" },
      { id: "verified", label: "ตรวจสอบและออก/เพิกถอน Verified ตามสิทธิ์", stage: "planned" },
      { id: "appeals", label: "ระบบอุทธรณ์และติดตามการระงับบัญชี", stage: "planned" },
    ],
  },
  {
    id: "food",
    title: "WYNOS Food",
    subtitle: "food.wynos.online · ร้านค้า อาหาร และคำสั่งซื้อ",
    capabilities: [
      { id: "food-overview", label: "ภาพรวมร้านอาหารและยอดคำสั่งซื้อ", stage: "existing-route", href: "/food" },
      { id: "food-orders", label: "ตรวจสอบคำสั่งซื้อที่มีสิทธิ์เข้าถึง", stage: "existing-route", href: "/food/orders", roles: ["admin"] },
      { id: "food-campaigns", label: "ดูแลแคมเปญและเงื่อนไขส่วนลด", stage: "existing-route", href: "/food/campaigns" },
      { id: "food-coupons", label: "จัดการคูปอง", stage: "existing-route", href: "/food/coupons" },
      { id: "food-push", label: "จัดการแจ้งเตือนโปรโมชัน Food", stage: "existing-route", href: "/food/notifications" },
      { id: "food-ads", label: "โฆษณา Food", stage: "existing-route", href: "/food/ads", roles: ["admin"] },
      { id: "food-places", label: "WYNOS Places ที่เกี่ยวกับ Food", stage: "existing-route", href: "/food/places" },
      { id: "food-refunds", label: "ข้อพิพาท การชดเชย และคืนเงินที่อนุมัติแล้ว", stage: "planned", roles: ["admin"] },
      { id: "food-coverage", label: "พื้นที่ให้บริการและกติกาการจัดส่ง", stage: "planned" },
    ],
  },
  {
    id: "merchant",
    title: "WYNOS Merchant",
    subtitle: "merchant.wynos.online · ธุรกิจและสิทธิ์ร้านค้า",
    capabilities: [
      { id: "merchant-applications", label: "พิจารณาคำขอสมัครร้านค้า", stage: "existing-route", href: "/merchants" },
      { id: "merchant-team", label: "ควบคุมสิทธิ์พนักงานและบัญชีธุรกิจ", stage: "planned" },
      { id: "merchant-menu", label: "ตรวจสอบเมนู หมวดหมู่ ราคา และตัวเลือกอาหาร", stage: "planned" },
      { id: "merchant-media", label: "ตรวจสอบสื่อที่อัปโหลดและหลักฐานร้าน", stage: "planned" },
      { id: "merchant-payout", label: "ติดตามการรับเงินและการจ่ายเงินแก่ร้าน", stage: "planned", roles: ["admin"] },
    ],
  },
  {
    id: "maps",
    title: "WYNOS Maps",
    subtitle: "maps.wynos.online · สถานที่ เส้นทาง และข้อมูลแผนที่",
    capabilities: [
      { id: "maps-places", label: "เพิ่ม/ตรวจสอบ/แก้ไขสถานที่และหมวดหมู่", stage: "planned" },
      { id: "maps-reports", label: "รายงานสถานที่ซ้ำหรือข้อมูลไม่ถูกต้อง", stage: "planned" },
      { id: "maps-photos", label: "กำกับดูแลรูปภาพและคำขอแก้ไข", stage: "planned" },
      { id: "maps-routing", label: "ตรวจสอบผู้ให้บริการเส้นทาง/แผนที่และโควต้า", stage: "planned" },
    ],
  },
  {
    id: "account",
    title: "WYNOS Account",
    subtitle: "บัญชีส่วนกลาง · สิทธิ์เข้าถึงและความปลอดภัย",
    capabilities: [
      { id: "account-evidence", label: "ดูหลักฐานการใช้งานตามบริการโดยไม่อ้างว่าเป็น SSO", stage: "planned", roles: ["admin"] },
      { id: "account-permissions", label: "จัดการสิทธิ์บัญชีแบบแยกบริการ", stage: "planned", roles: ["admin"] },
      { id: "account-sso", label: "Single Sign-On ทุกบริการและการเพิกถอน Session", stage: "planned" },
      { id: "account-privacy", label: "สิทธิ์ข้อมูลส่วนบุคคลและคำขอลบบัญชี", stage: "planned", roles: ["admin"] },
    ],
  },
  {
    id: "finance",
    title: "Finance & Payments",
    subtitle: "Stripe · ธุรกรรม ค่าธรรมเนียม และการกระทบยอด",
    capabilities: [
      { id: "finance-transactions", label: "ตรวจสอบธุรกรรมและสถานะ Stripe", stage: "planned", roles: ["admin"] },
      { id: "finance-ledger", label: "บัญชีแยกประเภทและรายงานการกระทบยอด", stage: "planned", roles: ["admin"] },
      { id: "finance-refunds", label: "คืนเงินที่ผ่านการอนุมัติและตรวจซ้ำจากผู้ให้บริการ", stage: "planned", roles: ["admin"] },
      { id: "finance-fees", label: "ควบคุมค่าธรรมเนียมและ GP แบบมีประวัติ", stage: "planned", roles: ["admin"] },
    ],
  },
  {
    id: "notifications",
    title: "Notifications & Support",
    subtitle: "In-App และ Web Push · ไม่มีการแจ้งเตือนทาง Email",
    capabilities: [
      { id: "notifications-inbox", label: "กล่องงานเจ้าหน้าที่และแจ้งเตือนจากระบบ", stage: "planned" },
      { id: "notifications-broadcast", label: "อนุมัติและส่ง Push ตามกลุ่มเป้าหมาย", stage: "planned", roles: ["admin"] },
      { id: "notifications-delivery", label: "ตรวจสอบสถานะการส่งและ Quiet Hours", stage: "planned" },
      { id: "support-cases", label: "เคสลูกค้า อุทธรณ์ และข้อพิพาทข้ามบริการ", stage: "planned" },
    ],
  },
  {
    id: "platform",
    title: "Platform Operations",
    subtitle: "Feature Flags · สุขภาพระบบและการตั้งค่าบริการ",
    capabilities: [
      { id: "action-center", label: "ดูงานค้างข้ามบริการตามสิทธิ์", stage: "existing-route", href: "/action-center" },
      { id: "platform-health", label: "ตรวจสุขภาพบริการและเหตุขัดข้อง", stage: "planned" },
      { id: "platform-flags", label: "กำหนด Feature Flags และทยอยเปิดบริการ", stage: "planned", roles: ["admin"] },
      { id: "platform-limits", label: "ตั้งค่าขีดจำกัดและนโยบายที่มี Backend รองรับ", stage: "planned", roles: ["admin"] },
      { id: "platform-incidents", label: "บันทึกเหตุขัดข้องและกระบวนการแก้ไข", stage: "planned" },
    ],
  },
  {
    id: "security",
    title: "Staff, Security & Audit",
    subtitle: "สิทธิ์เจ้าหน้าที่ · การอนุมัติ · ประวัติการดำเนินงาน",
    capabilities: [
      { id: "audit", label: "ประวัติการดำเนินงานของเจ้าหน้าที่", stage: "existing-route", href: "/audit-log" },
      { id: "staff-roles", label: "สิทธิ์เจ้าหน้าที่รายคำสั่งและขอบเขตบริการ", stage: "planned", roles: ["admin"] },
      { id: "mfa", label: "ตรวจสอบสถานะ MFA และ Session ของเจ้าหน้าที่", stage: "planned", roles: ["admin"] },
      { id: "approvals", label: "ระบบอนุมัติสองชั้นสำหรับคำสั่งเสี่ยงสูง", stage: "planned", roles: ["admin"] },
      { id: "audit-export", label: "ส่งออกรายงานแบบปกปิดข้อมูลส่วนบุคคล", stage: "planned", roles: ["admin"] },
    ],
  },
];

/** For release inventories, not for authorization decisions. */
export function summarizeAdminControlCoverage() {
  return ADMIN_CONTROL_AREAS.reduce(
    (acc, area) => {
      acc.existingRoutes += area.capabilities.filter((entry) => entry.stage === "existing-route").length;
      acc.planned += area.capabilities.filter((entry) => entry.stage === "planned").length;
      return acc;
    },
    { existingRoutes: 0, planned: 0 },
  );
}
