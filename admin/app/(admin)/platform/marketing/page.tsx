import { Suspense } from "react";
import Link from "next/link";

import { FoodBannerManager } from "@/components/admin/food-banner-manager";
import { FoodFeaturedManager } from "@/components/admin/food-featured-manager";
import { FoodHomeAnalytics } from "@/components/admin/food-home-analytics";
import { NoAccess } from "@/components/admin/no-access";
import { PlatformMarketingPreview } from "@/components/admin/platform-marketing-preview";
import { RefreshButton } from "@/components/admin/refresh-button";
import { fetchAdminFoodBanners, fetchAdminBannerStores } from "@/lib/admin-food-banners";
import { getFoodFeaturedAdminData } from "@/lib/admin-food-featured";
import { foodHomeAnalyticsDays } from "@/lib/admin-food-home-analytics";
import { marketingArea, marketingPanel, type MarketingArea } from "@/lib/admin-platform-marketing";
import { adminCan, requireAdminRole } from "@/lib/auth";

export default async function PlatformMarketingPage({ searchParams }: {
  searchParams: Promise<{ area?: string | string[]; panel?: string | string[]; analyticsDays?: string | string[] }>;
}) {
  const ctx = await requireAdminRole();
  if (!adminCan(ctx, "food")) return <NoAccess what="จัดการการตลาดหน้าแรก Food" />;

  const query = await searchParams;
  const area = marketingArea(query.area);
  const panel = marketingPanel(query.panel);
  const days = foodHomeAnalyticsDays(query.analyticsDays);

  return <div className="space-y-6 p-4 sm:p-6">
    <header className="flex flex-wrap items-start justify-between gap-3">
      <div className="space-y-2">
        <p className="text-xs text-muted-foreground">ส่วนกลางและระบบ / หน้าแรก Food</p>
        <h1 className="text-2xl font-semibold">Platform Marketing</h1>
        <p className="max-w-3xl text-sm leading-relaxed text-muted-foreground">
          จัดการตำแหน่งแบนเนอร์และร้านแนะนำบนหน้าแรก Food ตรวจรายการที่เผยแพร่จริง และดูสถิติรวม
          ขณะนี้รองรับหน้าแรก Food เท่านั้น แคมเปญที่ร้านเข้าร่วมอยู่ในหมวด Merchant
        </p>
      </div>
      <RefreshButton />
    </header>

    <nav aria-label="ตำแหน่งการตลาด" className="flex flex-wrap gap-2">
      {([['banners', 'แบนเนอร์ Food'], ['featured', 'ร้านแนะนำ Food']] as const).map(([value, label]) =>
        <Link key={value} prefetch={false} href={`?area=${value}&panel=${panel}&analyticsDays=${days}`}
          aria-current={area === value ? "page" : undefined}
          className={`min-h-11 rounded-lg border px-4 py-3 text-sm ${area === value ? "bg-muted font-semibold" : "hover:bg-muted/50"}`}>
          {label}
        </Link>)}
    </nav>

    <nav aria-label="งานการตลาด" className="flex flex-wrap gap-2 border-b pb-3">
      {([['manage', 'จัดการ'], ['preview', 'ตรวจการเผยแพร่'], ['analytics', 'สถิติ']] as const).map(([value, label]) =>
        <Link key={value} prefetch={false} href={`?area=${area}&panel=${value}&analyticsDays=${days}`}
          aria-current={panel === value ? "page" : undefined}
          className={`min-h-11 rounded-lg px-4 py-3 text-sm ${panel === value ? "bg-muted font-semibold" : "text-muted-foreground hover:bg-muted/50"}`}>
          {label}
        </Link>)}
    </nav>

    <Suspense key={`${area}:${panel}:${days}`} fallback={<p role="status" className="text-sm text-muted-foreground">กำลังโหลดข้อมูลการตลาด...</p>}>
      {panel === "manage" ? <MarketingEditor area={area} canEdit={adminCan(ctx, "food", "edit")} />
        : panel === "preview" ? <PlatformMarketingPreview area={area} />
          : <FoodHomeAnalytics kind={area === "banners" ? "banner" : "featured"} days={days}
            queryParams={{ area, panel: "analytics" }} />}
    </Suspense>
  </div>;
}

async function MarketingEditor({ area, canEdit }: { area: MarketingArea; canEdit: boolean }) {
  let data;
  try {
    data = await fetchEditorData(area);
  } catch {
    return <p role="alert" className="rounded-xl border p-4 text-sm text-muted-foreground">
      โหลดข้อมูลสำหรับจัดการไม่สำเร็จ กรุณารีเฟรชหรือตรวจสอบสิทธิ์และการเชื่อมต่อ
    </p>;
  }
  return data.area === "banners"
    ? <FoodBannerManager initial={data.rows} stores={data.stores} canEdit={canEdit} />
    : <FoodFeaturedManager initial={data.rows} stores={data.stores} canEdit={canEdit} />;
}

async function fetchEditorData(area: MarketingArea) {
  if (area === "banners") {
    const [rows, stores] = await Promise.all([fetchAdminFoodBanners(), fetchAdminBannerStores()]);
    return { area, rows, stores };
  }
  return { area, ...await getFoodFeaturedAdminData() };
}
