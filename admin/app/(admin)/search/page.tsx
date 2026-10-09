import Link from "next/link";
import { ArrowUpRight, Search, ShieldCheck } from "lucide-react";

import { requireAdminRole } from "@/lib/auth";
import { parseAdminSearchQuery } from "@/lib/admin-search-query.mjs";
import { fetchAdminGlobalSearch } from "@/lib/admin-global-search";

export default async function AdminGlobalSearchPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string | string[] }>;
}) {
  await requireAdminRole();
  const params = await searchParams;
  let term = "";
  let hasQuery = false;
  let invalid = "";

  try {
    const validated = parseAdminSearchQuery(params.q);
    term = validated.query;
    hasQuery = validated.hasQuery;
  } catch {
    invalid = "คำค้นหาไม่ถูกต้อง กรุณาใช้ชื่อผู้ใช้ ชื่อร้าน หรือหมายเลขออเดอร์ 3–48 ตัวอักษร";
  }

  const sections = hasQuery && !invalid ? await fetchAdminGlobalSearch(term) : [];

  return (
    <div className="flex flex-col gap-5 p-4 sm:p-6">
      <header className="space-y-2">
        <p className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
          WYNOS Admin · Global Search
        </p>
        <h1 className="text-2xl font-semibold tracking-tight">ค้นหาข้อมูลสำหรับผู้ดูแล</h1>
        <p className="text-sm leading-relaxed text-muted-foreground">
          ค้นหาชื่อผู้ใช้ ชื่อร้านอาหาร และหมายเลขออเดอร์จากระบบที่คุณได้รับอนุญาต
          ไม่รองรับการค้นหาจากเบอร์โทรศัพท์หรืออีเมล
        </p>
      </header>
      <form method="get" action="/search" role="search" className="flex flex-col gap-3 rounded-xl border bg-background p-4 sm:flex-row">
        <label htmlFor="admin-global-search" className="sr-only">ค้นหาข้อมูล WYNOS Admin</label>
        <div className="relative min-w-0 flex-1">
          <Search aria-hidden="true" className="absolute left-3 top-3 size-5 text-muted-foreground" />
          <input
            id="admin-global-search"
            name="q"
            type="search"
            defaultValue={term}
            autoComplete="off"
            placeholder="ชื่อผู้ใช้ ชื่อร้าน หรือหมายเลขออเดอร์"
            minLength={3}
            maxLength={48}
            required
            className="min-h-11 w-full rounded-lg border bg-background pl-10 pr-3 text-sm"
          />
        </div>
        <button type="submit" className="min-h-11 shrink-0 rounded-lg bg-foreground px-5 text-sm font-medium text-background">
          ค้นหา
        </button>
      </form>
      {invalid ? (
        <p role="alert" className="rounded-lg border p-4 text-sm text-muted-foreground">{invalid}</p>
      ) : !hasQuery ? (
        <p className="flex items-center gap-2 rounded-xl border bg-background p-4 text-sm text-muted-foreground">
          <ShieldCheck aria-hidden="true" className="size-4" />
          เริ่มค้นหาด้วยข้อมูลทั่วไปที่ไม่ใช่ข้อมูลส่วนตัว
        </p>
      ) : (
        <section aria-label="ผลการค้นหา" className="grid gap-4 lg:grid-cols-2">
          {sections.map((section) => (
            <div key={section.id} className="min-w-0 overflow-hidden rounded-xl border bg-background">
              <div className="flex items-center justify-between gap-2 border-b p-4">
                <h2 className="font-semibold">{section.label}</h2>
                <span className="rounded-full bg-muted px-2.5 py-1 text-xs font-medium">
                  {section.status === "ready" ? section.results.length + " รายการ" : "ไม่พร้อม"}
                </span>
              </div>
              {section.status === "unavailable" ? (
                <p role="status" className="p-4 text-sm text-muted-foreground">
                  ไม่สามารถตรวจสอบข้อมูลหมวดนี้ได้ในขณะนี้ กรุณาลองอีกครั้ง
                </p>
              ) : section.results.length === 0 ? (
                <p className="p-4 text-sm text-muted-foreground">ไม่พบรายการในหมวดนี้</p>
              ) : (
                <ul className="divide-y">
                  {section.results.map((item) => (
                    <li key={item.id}>
                      <Link href={item.href} className="flex min-h-14 items-center justify-between gap-2 px-4 py-3 hover:bg-accent">
                        <span className="min-w-0">
                          <span className="block truncate text-sm font-medium">{item.label}</span>
                          <span className="block truncate text-xs text-muted-foreground">{item.sublabel}</span>
                        </span>
                        <ArrowUpRight aria-hidden="true" className="size-4 shrink-0 text-muted-foreground" />
                      </Link>
                    </li>
                  ))}
                </ul>
              )}
            </div>
          ))}
          <p className="text-xs text-muted-foreground lg:col-span-2">
            แสดงผลตามสิทธิ์บัญชีเจ้าหน้าที่ หมวดที่เข้าถึงไม่ได้จะไม่ถูกค้นหาหรือส่งข้อมูลมาที่หน้าเว็บ
            · จำกัดสูงสุด 6 รายการต่อหมวด
          </p>
        </section>
      )}
    </div>
  );
}
