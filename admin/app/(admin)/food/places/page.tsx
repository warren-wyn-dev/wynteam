import Link from "next/link";
import { ArrowLeft, MapPinned } from "lucide-react";

import { WynosPlacesManager } from "@/components/admin/wynos-places-manager";
import { fetchAdminWynosPlaces } from "@/lib/admin-food";
import { requireAdminRole } from "@/lib/auth";

export default async function WynosPlacesPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; category?: string; status?: string }>;
}) {
  await requireAdminRole();
  const params = await searchParams;
  const places = await fetchAdminWynosPlaces({
    query: params.q,
    category: params.category,
    status: params.status,
    limit: 500,
  });

  return (
    <div className="flex flex-col gap-6 p-6">
      <Link href="/food" className="inline-flex w-fit items-center gap-1 text-sm text-muted-foreground hover:text-foreground">
        <ArrowLeft className="size-4" /> WYNOS Food
      </Link>

      <section className="flex flex-col gap-1">
        <div className="flex items-center gap-2">
          <MapPinned className="size-5" />
          <h2 className="text-xl font-semibold">WYNOS Places Manager</h2>
        </div>
        <p className="text-sm text-muted-foreground">จัดการสถานที่สาธารณะ, Merchant Places, Verification และข้อมูลนำเข้าสำหรับ WYNOS Maps</p>
      </section>

      <form action="/food/places" className="grid gap-2 rounded-xl border p-4 md:grid-cols-[minmax(0,1fr)_180px_180px_auto]">
        <input name="q" defaultValue={params.q ?? ""} placeholder="ค้นหาชื่อ ที่อยู่ หรือ source ref" className="h-10 rounded-md border bg-background px-3 text-sm" />
        <select name="category" defaultValue={params.category ?? ""} className="h-10 rounded-md border bg-background px-3 text-sm">
          <option value="">ทุกประเภท</option>
          <option value="restaurant">ร้านอาหาร</option>
          <option value="store">ร้านค้า</option>
          <option value="building">อาคาร</option>
          <option value="residence">ที่พักอาศัย</option>
          <option value="pickup_point">จุดรับอาหาร</option>
          <option value="entrance">ทางเข้า</option>
          <option value="poi">จุดสำคัญ</option>
          <option value="place">สถานที่</option>
        </select>
        <select name="status" defaultValue={params.status ?? ""} className="h-10 rounded-md border bg-background px-3 text-sm">
          <option value="">ทุกสถานะ</option>
          <option value="active">กำลังแสดง</option>
          <option value="inactive">ซ่อนอยู่</option>
          <option value="wynos_verified">WYNOS Verified</option>
          <option value="merchant_verified">Merchant Verified</option>
          <option value="unverified">ยังไม่ยืนยัน</option>
        </select>
        <button type="submit" className="h-10 rounded-md border px-4 text-sm font-medium hover:bg-accent">กรอง</button>
      </form>

      <WynosPlacesManager places={places} />
    </div>
  );
}
