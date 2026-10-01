import Link from "next/link";

import { MerchantApplicationCard } from "@/components/admin/merchant-review-card";
import {
  fetchMerchantApplications,
  type MerchantApplicationStatus,
} from "@/lib/admin-merchants";
import { requireAdminRole } from "@/lib/auth";
import { cn } from "@/lib/utils";

const FILTERS: Array<{ value: "all" | MerchantApplicationStatus; label: string }> = [
  { value: "pending", label: "รอตรวจสอบ" },
  { value: "approved", label: "อนุมัติแล้ว" },
  { value: "rejected", label: "ปฏิเสธแล้ว" },
  { value: "all", label: "ทั้งหมด" },
];

export default async function MerchantApplicationsPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string }>;
}) {
  const { role } = await requireAdminRole();
  const { status } = await searchParams;
  const resolved = FILTERS.some((item) => item.value === status) ? status! : "pending";
  const applications = await fetchMerchantApplications(
    resolved === "all" ? undefined : (resolved as MerchantApplicationStatus),
  );

  return (
    <div className="flex flex-col gap-5 p-6">
      <section className="flex flex-col gap-2">
        <div>
          <h2 className="text-xl font-semibold">คำขอ WYNOS Merchant</h2>
          <p className="mt-1 text-sm text-muted-foreground">
            ตรวจสอบข้อมูลร้าน อนุมัติ เปิดสิทธิ์ Merchant สำหรับร้านอาหาร และส่งเหตุผลกลับเมื่อปฏิเสธ
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          {FILTERS.map((filter) => (
            <Link
              key={filter.value}
              href={filter.value === "pending" ? "/merchants" : `/merchants?status=${filter.value}`}
              className={cn(
                "inline-flex min-h-11 items-center rounded-full border px-4 text-sm font-medium transition-colors",
                resolved === filter.value
                  ? "border-foreground bg-foreground text-background"
                  : "bg-background text-muted-foreground hover:bg-muted hover:text-foreground",
              )}
            >
              {filter.label}
            </Link>
          ))}
        </div>
      </section>

      {applications.length === 0 ? (
        <div className="rounded-xl border border-dashed p-10 text-center">
          <p className="font-medium">ไม่มีคำขอในสถานะนี้</p>
          <p className="mt-1 text-sm text-muted-foreground">เมื่อมีผู้สมัคร Merchant รายการจะปรากฏที่นี่</p>
        </div>
      ) : (
        <div className="grid gap-3">
          {applications.map((application) => (
            <MerchantApplicationCard
              key={application.id}
              application={application}
              role={role}
            />
          ))}
        </div>
      )}
    </div>
  );
}
