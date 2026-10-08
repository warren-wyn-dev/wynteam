import Link from "next/link";
import { requireAdminRole } from "@/lib/auth";
import { fetchFoodGpDrafts } from "@/lib/admin-food-gp";
import { FoodGpDraftEditor } from "@/components/admin/food-gp-draft-editor";

export const dynamic = "force-dynamic";

/** WYNOS Admin: sandbox-only GP draft control; production remains untouched. */
export default async function FoodGpDraftPage() {
  const { role } = await requireAdminRole();
  if (role !== "admin") {
    return <main className="p-6"><p className="rounded-xl border p-6 text-sm">
      เฉพาะผู้ดูแล WYNOS Admin เท่านั้นที่ตั้งอัตรา GP ได้
    </p></main>;
  }

  if (process.env.NEXT_PUBLIC_SUPABASE_URL !== "https://pcatuxtenluqzjzzwsvl.supabase.co") {
    return <main className="flex flex-col gap-4 p-6">
      <h1 className="text-xl font-semibold">WYNOS GP</h1>
      <p className="rounded-xl border p-6 text-sm text-muted-foreground">
        ระบบกำหนด GP ยังเปิดให้ใช้งานเฉพาะ WYNOS Sandbox เท่านั้น
        ไม่ได้เปิดให้แก้ไขบน Production
      </p>
    </main>;
  }

  let stores;
  try {
    stores = await fetchFoodGpDrafts();
  } catch {
    return <main className="flex flex-col gap-4 p-6">
      <h1 className="text-xl font-semibold">WYNOS GP · Sandbox</h1>
      <p className="rounded-xl border p-6 text-sm text-muted-foreground">
        หน้านี้พร้อมแล้ว แต่ยังไม่ได้แต่งตั้งผู้ดูแล GP ใน Sandbox
        ต้องให้ผู้ดูแลระบบกำหนดสิทธิ์ผ่านตาราง allowlist โดย service role ก่อน
        ร้านค้าทั่วไปและผู้ตรวจสอบเนื้อหาไม่มีสิทธิ์แก้ GP
      </p>
      <Link href="/food" className="text-sm underline">กลับหน้าร้านอาหาร</Link>
    </main>;
  }

  return <main className="flex flex-col gap-6 p-6">
    <div className="flex flex-wrap items-center justify-between gap-3">
      <div>
        <h1 className="text-xl font-semibold">WYNOS GP · Sandbox</h1>
        <p className="mt-1 text-sm text-muted-foreground">
          ค่าคอมมิชชันรายร้าน · ตั้งเปอร์เซ็นต์ภายหลัง · คำนวณตัวอย่างโดยไม่หักเงินจริง
        </p>
      </div>
      <span className="rounded-full border px-3 py-1 text-xs">Simulation Only</span>
    </div>
    <FoodGpDraftEditor stores={stores} />
  </main>;
}
