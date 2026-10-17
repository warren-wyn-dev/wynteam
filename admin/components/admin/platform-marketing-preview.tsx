import Image from "next/image";

import { fetchMarketingPreview, type MarketingArea } from "@/lib/admin-platform-marketing";

export async function PlatformMarketingPreview({ area }: { area: MarketingArea }) {
  let preview;
  try {
    preview = await fetchMarketingPreview(area);
  } catch {
    return <section className="space-y-2 rounded-xl border p-4">
      <h2 className="font-semibold">ตรวจรายการที่เผยแพร่ขณะนี้</h2>
      <p role="alert" className="text-sm text-muted-foreground">
        ตรวจรายการที่เผยแพร่ไม่สำเร็จ กรุณารีเฟรชหรือตรวจสอบการเชื่อมต่อ จึงยังสรุปไม่ได้ว่ามีรายการใดแสดงอยู่
      </p>
    </section>;
  }

  const checkedAt = new Intl.DateTimeFormat("th-TH", {
    dateStyle: "medium", timeStyle: "medium", timeZone: "Asia/Bangkok",
  }).format(new Date(preview.checkedAt));

  return <section className="space-y-5 rounded-xl border p-4 sm:p-5" aria-label="รายการที่เผยแพร่ขณะนี้">
    <div className="space-y-2">
      <h2 className="font-semibold">รายการที่ผ่านเงื่อนไขเผยแพร่ขณะนี้</h2>
      <p className="text-xs text-muted-foreground">ตรวจเมื่อ {checkedAt} (เวลาไทย UTC+7) · รีเฟรชเพื่อตรวจใหม่</p>
      <p className="text-sm leading-relaxed text-muted-foreground">
        {area === "banners"
          ? "แสดงแบนเนอร์ที่เปิดใช้งาน อยู่ในช่วงเวลา และไม่มีร้านปลายทางที่ยังไม่เผยแพร่หรือถูกระงับ ตามลำดับจากระบบ สูงสุด 8 รายการ"
          : "แสดงร้านแนะนำที่เปิดใช้งาน อยู่ในช่วงเวลา ร้านเผยแพร่และไม่ถูกระงับ ตามลำดับจากระบบ สูงสุด 20 ร้าน"}
        {" "}ร้านที่ปิดรับออเดอร์ชั่วคราวอาจยังปรากฏในรายการนี้
      </p>
      <p className="rounded-lg bg-muted/40 p-3 text-sm leading-relaxed">
        {area === "banners"
          ? "ภาพตัวอย่างนี้ใช้รายการเผยแพร่จริง การกดไปยังร้านในหน้าลูกค้าขึ้นกับร้านที่ลูกค้าดูได้ในพื้นที่นั้น หากไม่มีร้านปลายทางในรายการของลูกค้า ภาพจะกดไปยังร้านไม่ได้"
          : "นี่คือรายการร้านที่ผ่านเงื่อนไขเผยแพร่ ลูกค้าแต่ละคนอาจเห็นร้านแนะนำน้อยกว่านี้ตามพื้นที่บริการ คำค้น หมวดหมู่ และตัวกรองของตน"}
      </p>
    </div>

    {preview.items.length === 0 ? <p className="rounded-lg border border-dashed p-4 text-sm text-muted-foreground">
      ขณะตรวจสอบไม่มี{area === "banners" ? "แบนเนอร์" : "ร้านแนะนำ"}ที่ผ่านเงื่อนไขเผยแพร่
    </p> : preview.area === "banners" ? <ol className="grid gap-4 lg:grid-cols-2">
      {preview.items.map((item, index) => <li key={item.id} className="min-w-0 overflow-hidden rounded-xl border">
        <Image src={item.imageUrl} alt={item.title} width={960} height={480} unoptimized
          className="aspect-[2/1] w-full bg-muted object-cover" />
        <div className="space-y-2 p-4">
          <h3 className="break-words font-medium">{index + 1}. {item.title}</h3>
          {item.subtitle ? <p className="break-words text-sm text-muted-foreground">{item.subtitle}</p> : null}
          <p className="break-all text-xs text-muted-foreground">
            {item.destinationStoreId ? `ร้านปลายทาง: ${item.destinationStoreId}` : "ภาพไม่มีลิงก์ไปร้าน"}
          </p>
        </div>
      </li>)}
    </ol> : <>
      {!preview.namesAvailable ? <p role="status" className="text-sm text-muted-foreground">
        โหลดชื่อร้านไม่สำเร็จ จึงแสดงรหัสร้านตามรายการเผยแพร่ที่ตรวจได้
      </p> : null}
      <ol className="space-y-3">
        {preview.items.map((item, index) => <li key={item.storeId} className="flex items-start gap-3 rounded-lg border p-4">
          <span className="shrink-0 text-sm text-muted-foreground">{index + 1}.</span>
          <div className="min-w-0 space-y-1">
            <h3 className="break-words font-medium">{item.storeName ?? "ชื่อร้านยังไม่พร้อมแสดง"}</h3>
            <p className="break-all text-xs text-muted-foreground">{item.storeId}</p>
            <p className="text-sm text-muted-foreground">ลำดับที่ตั้งไว้ {item.priority}</p>
          </div>
        </li>)}
      </ol>
    </>}
  </section>;
}
