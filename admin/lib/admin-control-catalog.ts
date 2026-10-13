import type { AdminSystem } from "@/lib/admin-systems";

/**
 * Admin control inventory, not a switchboard. A live href is an existing route,
 * not a claim that every feature inside that category is implemented.
 * Entries without href are intentionally non-interactive until their backend,
 * authorization checks, audit and production QA exist.
 */
export type ControlItem = {
  name: string;
  description: string;
  href?: string;
  access?: AdminSystem;
  editOnly?: boolean;
  superAdminOnly?: boolean;
};
export type ControlGroup = { name: string; items: ControlItem[] };
export type ControlArea = "food" | "merchant";

export const FOOD_CONTROLS: ControlGroup[] = [
  { name: "ประสบการณ์ลูกค้า", items: [
    { name: "ภาพรวม Food", description: "สรุปการใช้งานและสถานะของบริการ", href: "/dashboard/food" },
    { name: "หน้าแรกและลำดับร้าน", description: "ตำแหน่งร้านแนะนำ ร้านยอดนิยม ร้านเปิดใหม่ และการจัดอันดับ" },
    { name: "แบนเนอร์หน้าแรก", description: "อัปโหลด จัดลำดับ ตั้งเวลาทำงาน ลิงก์และวัดยอดคลิก" },
    { name: "การค้นหาและตัวกรอง", description: "คำค้น หมวดหมู่ ตัวกรอง ผลค้นหาและการแสดงผล" },
    { name: "การแสดงร้านอาหาร", description: "ซ่อน/แสดงร้านและกฎการปรากฏต่อผู้ใช้" },
    { name: "การตั้งค่าหน้า Food", description: "ภาษา ข้อความ นโยบาย และการเปิดปิดองค์ประกอบ" },
  ]},
  { name: "การสั่งซื้อและลูกค้า", items: [
    { name: "คำสั่งซื้อทั้งหมด", description: "ตรวจสถานะ ไทม์ไลน์และหลักฐานจากทุกร้าน", href: "/food/orders", editOnly: true },
    { name: "บัญชีลูกค้า Food", description: "ประวัติการซื้อ ข้อจำกัดสิทธิ์ และการดูข้อมูลตามสิทธิ์" },
    { name: "ชำระเงินและคืนเงิน", description: "รายการชำระเงิน Stripe/สลิป รายการคืนเงินและข้อพิพาท" },
    { name: "ศูนย์ช่วยเหลือลูกค้า", description: "ข้อร้องเรียน หลักฐาน คำชดเชยและการติดตามปัญหา" },
    { name: "รีวิวและคุณภาพ", description: "รายงาน รีวิวที่ผิดนโยบาย และการดำเนินการตรวจสอบ" },
  ]},
  { name: "การตลาดและราคา", items: [
    { name: "โปรโมชันและแคมเปญ", description: "แคมเปญระดับแพลตฟอร์มและการแบ่งภาระส่วนลด", href: "/food/campaigns" },
    { name: "สิทธิ์ลูกค้าใหม่", description: "ข้อเสนอครั้งแรก เงื่อนไขการใช้และสิทธิ์ต่อบัญชี", href: "/food/campaigns" },
    { name: "ค่าธรรมเนียมออเดอร์", description: "ตั้งเกณฑ์คำสั่งซื้อขนาดเล็กและค่าบริการ" },
    { name: "ค่าส่งฝั่งลูกค้า", description: "อัตราส่วนเพิ่ม เพดานราคาและส่วนลดค่าส่ง" },
    { name: "Push และ In-App", description: "ข้อความการตลาด การตั้งเวลาส่งและกลุ่มเป้าหมาย", href: "/food/notifications" },
  ]},
  { name: "คุณภาพระบบและการปฏิบัติการ", items: [
    { name: "พื้นที่ให้บริการ", description: "เปิด/ปิดจังหวัด เขตและโซนตามความพร้อม" },
    { name: "การป้องกันการทุจริต", description: "ความเสี่ยงคำสั่งซื้อ บัญชีซ้ำและการใช้คูปองผิดเงื่อนไข" },
    { name: "รายงานและการวิเคราะห์", description: "คำสั่งซื้อ ลูกค้า ยอดขาย แคมเปญและการเปลี่ยนแปลง" },
    { name: "ควบคุมเหตุฉุกเฉิน", description: "ระงับการรับออเดอร์อย่างมีขอบเขตและติดตามการกู้คืน" },
  ]},
];

export const MERCHANT_CONTROLS: ControlGroup[] = [
  { name: "ร้านค้าและบุคลากร", items: [
    { name: "ภาพรวม Merchant", description: "สถานะร้านและภาพรวมการดำเนินงาน", href: "/dashboard/merchant" },
    { name: "ร้านอาหารทั้งหมด", description: "ตรวจและระงับร้าน จัดการข้อมูลและทีมร้าน", href: "/food", access: "food" },
    { name: "อนุมัติและยืนยันร้าน", description: "ตรวจใบสมัครและหลักฐานผู้ประกอบการ", href: "/merchants" },
    { name: "เจ้าของร้านและพนักงาน", description: "บทบาท ทีมร้านและขอบเขตการเข้าถึง", href: "/food", access: "food" },
    { name: "การจัดการหลายสาขา", description: "สิทธิ์/พิกัด/เวลา/การเงินแยกสาขา" },
  ]},
  { name: "เมนูและการรับออเดอร์", items: [
    { name: "เมนูอาหาร", description: "จัดการชื่อ ราคา หมวดหมู่ รายละเอียด สต็อกต่อวัน และเปิด/ปิดขาย (รูปและ Add-ons ยังต้องพัฒนาต่อ)", href: "/merchant/menu" },
    { name: "หมวดหมู่เมนู", description: "เพิ่ม ลบ และจัดลำดับหมวดอาหาร" },
    { name: "ตัวเลือกเสริม", description: "ขนาด ความเผ็ด ท็อปปิง และราคาตัวเลือก" },
    { name: "สต็อกและการเปิดขาย", description: "จำนวนสินค้าคงเหลือและเมนูที่หยุดขาย" },
    { name: "รับออเดอร์และเวลาเตรียม", description: "การรับงาน ระยะเวลาเตรียม ยกเลิกและข้อจำกัด" },
    { name: "เวลาเปิดปิดร้าน", description: "ตารางบริการ วันหยุด และหยุดรับออเดอร์ชั่วคราว" },
  ]},
  { name: "การตลาดและการเงินร้าน", items: [
    { name: "GP รายร้าน", description: "กำหนดอัตรา GP พร้อมประวัติและการอนุมัติสำหรับ super admin", href: "/merchant/finance?view=gp", superAdminOnly: true },
    { name: "ค่าคอมมิชชันและยอดหัก", description: "ดูยอดเงินและ GP ที่เกี่ยวข้องกับร้าน", href: "/merchant/finance" },
    { name: "คูปองร้านค้า", description: "สร้าง/จัดการคูปองที่มีในระบบ", href: "/food/coupons", access: "food" },
    { name: "แคมเปญร้าน", description: "ร้านเข้าร่วมแคมเปญและแบ่งรับผิดชอบส่วนลด", href: "/food/campaigns", access: "food" },
    { name: "โฆษณาร้านค้า", description: "บริหาร CPC เครดิตและการตรวจสลิปเติมเงิน", href: "/food/ads", access: "food", editOnly: true },
    { name: "การเงินร้าน", description: "ยอดรับเงิน ค้างจ่าย ประวัติโอน และ Stripe payout", href: "/merchant/finance" },
    { name: "บัญชีรับเงินร้าน", description: "ตรวจความพร้อมบัญชี Stripe และข้อมูลสำหรับการจ่ายเงิน", href: "/merchant/finance" },
  ]},
  { name: "การส่งอาหารและพื้นที่", items: [
    { name: "ค่าส่งร้านค้า", description: "แก้ค่าส่งเริ่มต้นและอัตราต่อกิโลเมตรของร้านในระบบจริง", href: "/merchant/delivery" },
    { name: "รัศมีจัดส่ง", description: "แก้รัศมีจัดส่งตามพิกัดต่อร้าน; โซนตามถนนยังรอพัฒนา", href: "/merchant/delivery" },
    { name: "เครื่องคำนวณค่าส่ง", description: "ลองคำนวณค่าจัดส่งตามสูตรร้านจัดส่งเองที่ใช้อยู่", href: "/merchant/delivery" },
    { name: "วิธีจัดส่ง", description: "ร้านส่งเอง รับที่ร้าน และเปิดใช้ WYNOS Rider เมื่อพร้อม" },
  ]},
  { name: "ตรวจสอบร้าน", items: [
    { name: "คุณภาพและคะแนนร้าน", description: "ข้อร้องเรียน อัตรายกเลิก การเตรียมและรีวิว" },
    { name: "การแจ้งเตือนร้าน", description: "ข่าวสารและแคมเปญสำหรับ Merchant", href: "/food/notifications", access: "food" },
    { name: "สถิติร้านอาหาร", description: "ยอดขาย เมนูขายดี รายงานรายสาขา", href: "/merchant/finance" },
    { name: "สิทธิ์แก้ไขของร้าน", description: "กำหนดสิ่งที่ร้านเปลี่ยนเองได้เทียบกับนโยบายกลาง" },
    { name: "ประวัติการแก้ไข", description: "บันทึกสิทธิ์ ผู้แก้ไข ก่อน/หลัง และเหตุผล", href: "/audit-log", superAdminOnly: true },
  ]},
];

export const SHARED_CONTROLS: ControlGroup[] = [
  { name: "โครงสร้างส่วนกลางที่ต้องขยาย", items: [
    { name: "บัญชีและกระทบยอดเงิน", description: "ยอด Stripe, GP, ส่วนลด และยอดค้างชำระ" },
    { name: "ออเดอร์ผิดปกติ", description: "สลิปผิด สถานะค้าง และคำสั่งซื้อที่ชำระแล้วไม่เข้าสู่ร้าน" },
    { name: "กฎการจัดส่งกลาง", description: "รูปแบบราคา/พื้นที่ร่วมกันโดยแยกผู้จัดส่ง" },
    { name: "การจัดการหลายสาขา", description: "เจ้าของหนึ่งรายดูแลหลายสาขาโดยไม่ปะปนข้อมูล" },
    { name: "การตรวจเอกสารร้าน", description: "วันหมดอายุและขั้นตอนตรวจสอบ" },
    { name: "ข้อพิพาทและคืนเงิน", description: "หลักฐานและการตัดสินความรับผิดชอบ" },
    { name: "ระงับฉุกเฉินเฉพาะพื้นที่", description: "สวิตช์ที่ต้องอนุมัติและมีผลต่อระบบจริง" },
    { name: "ตรวจสุขภาพระบบเรียลไทม์", description: "Health/latency/error ของ payment, orders, notifications" },
    { name: "กฎตั้งค่าหลายระดับ", description: "ค่าทั้งระบบ → พื้นที่ → ร้าน → รายการ พร้อมกำหนดเวลา" },
    { name: "ความปลอดภัยและบันทึก", description: "สิทธิ์เฉพาะงาน 2FA audit และอนุมัติสำหรับงานเสี่ยง", href: "/team", superAdminOnly: true },
  ]},
];

export const controlCount = (groups: ControlGroup[]) =>
  groups.reduce((sum, group) => sum + group.items.length, 0);
