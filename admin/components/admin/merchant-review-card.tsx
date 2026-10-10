"use client";

import Link from "next/link";
import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { CheckCircle2, Clock3, ExternalLink, Store, XCircle } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Textarea } from "@/components/ui/textarea";
import { reviewMerchantApplication } from "@/lib/admin-merchant-actions";
import type { AdminMerchantApplication } from "@/lib/admin-merchants";

const BUSINESS_LABEL: Record<AdminMerchantApplication["business_type"], string> = {
  food: "อาหาร / เครื่องดื่ม",
  retail: "ร้านค้าสินค้า",
  service: "บริการ",
  other: "อื่น ๆ",
};

function statusBadge(application: AdminMerchantApplication) {
  if (application.status === "approved") {
    return (
      <Badge variant="secondary" className="gap-1">
        <CheckCircle2 className="size-3" />
        {application.merchant_access_enabled ? "อนุมัติ · เปิดสิทธิ์แล้ว" : "อนุมัติแล้ว"}
      </Badge>
    );
  }
  if (application.status === "rejected") {
    return (
      <Badge variant="destructive" className="gap-1">
        <XCircle className="size-3" />
        ปฏิเสธแล้ว
      </Badge>
    );
  }
  return (
    <Badge variant="outline" className="gap-1">
      <Clock3 className="size-3" />
      รอตรวจสอบ
    </Badge>
  );
}

function formatDate(value: string) {
  return new Intl.DateTimeFormat("th-TH", {
    dateStyle: "medium",
    timeStyle: "short",
    timeZone: "Asia/Bangkok",
  }).format(new Date(value));
}

const MERCHANT_APPLICATION_STATUS_LABEL: Record<string, string> = {
  pending: "รอตรวจ",
  approved: "อนุมัติแล้ว",
  rejected: "ปฏิเสธแล้ว",
};

/** WYN-214: server messages in Thai for the reviewer. */
function merchantReviewError(error: unknown, fallback: string) {
  const message = error instanceof Error ? error.message : String((error as { message?: string })?.message ?? "");
  if (message.includes("Only admins can review merchant applications")) return "เฉพาะ Admin เท่านั้นที่อนุมัติหรือปฏิเสธคำขอได้";
  if (message.includes("Approved merchant applications are final")) return "คำขอนี้อนุมัติไปแล้ว เปลี่ยนไม่ได้";
  if (message.includes("Rejection reason is required")) return "กรุณาใส่เหตุผลที่ปฏิเสธ";
  if (message.includes("Merchant application not found")) return "ไม่พบคำขอนี้ อาจถูกลบไปแล้ว ลองรีเฟรช";
  return fallback;
}

export function MerchantApplicationCard({
  application,
  canReview: canReviewMerchants,
}: {
  application: AdminMerchantApplication;
  /** merchant:edit (WYN-219); the RPC re-checks. */
  canReview: boolean;
}) {
  const router = useRouter();
  const [detailsOpen, setDetailsOpen] = useState(false);
  const [rejectOpen, setRejectOpen] = useState(false);
  const [reason, setReason] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  const canReview = canReviewMerchants && application.status !== "approved";

  function approve() {
    // WYN-214: approval is final and creates the store; confirm first.
    const what = application.business_type === "food" ? "อนุมัติและเปิด Merchant ให้ร้านนี้" : "อนุมัติคำขอนี้";
    if (!window.confirm(`${what}? อนุมัติแล้วย้อนกลับไม่ได้`)) return;
    setError(null);
    startTransition(async () => {
      try {
        await reviewMerchantApplication({
          applicationId: application.id,
          decision: "approved",
        });
        setDetailsOpen(false);
        router.refresh();
      } catch (err) {
        setError(merchantReviewError(err, "อนุมัติไม่สำเร็จ"));
      }
    });
  }

  function reject() {
    const trimmed = reason.trim();
    if (!trimmed) return;
    setError(null);
    startTransition(async () => {
      try {
        await reviewMerchantApplication({
          applicationId: application.id,
          decision: "rejected",
          reason: trimmed,
        });
        setRejectOpen(false);
        setDetailsOpen(false);
        setReason("");
        router.refresh();
      } catch (err) {
        setError(merchantReviewError(err, "ปฏิเสธคำขอไม่สำเร็จ"));
      }
    });
  }

  return (
    <>
      <article className="rounded-xl border bg-card p-4 sm:p-5">
        <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
          <div className="min-w-0 space-y-2">
            <div className="flex flex-wrap items-center gap-2">
              <h2 className="truncate text-base font-semibold">{application.business_name}</h2>
              {statusBadge(application)}
            </div>
            <div className="flex flex-wrap gap-x-4 gap-y-1 text-sm text-muted-foreground">
              <span>{BUSINESS_LABEL[application.business_type]}</span>
              <span>@{application.applicant_username ?? "ไม่พบ username"}</span>
              <span>{application.phone}</span>
            </div>
            <p className="line-clamp-2 text-sm text-muted-foreground">{application.address}</p>
            <p className="text-xs text-muted-foreground">
              ส่งคำขอ {formatDate(application.created_at)}
            </p>
          </div>
          <Button type="button" variant="outline" onClick={() => setDetailsOpen(true)}>
            ดูรายละเอียด
          </Button>
        </div>
      </article>

      <Dialog open={detailsOpen} onOpenChange={setDetailsOpen}>
        <DialogContent className="max-h-[88vh] overflow-y-auto sm:max-w-2xl">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              <Store className="size-5" />
              {application.business_name}
            </DialogTitle>
            <DialogDescription>
              คำขอ WYNOS Merchant · {BUSINESS_LABEL[application.business_type]}
            </DialogDescription>
          </DialogHeader>

          <div className="grid gap-3 text-sm sm:grid-cols-2">
            <Info label="ผู้สมัคร" value={application.applicant_display_name || application.applicant_username || application.user_id} />
            <Info label="Username" value={application.applicant_username ? `@${application.applicant_username}` : "-"} />
            <Info label="ชื่อผู้ติดต่อ" value={application.contact_name} />
            <Info label="เบอร์โทร" value={application.phone} />
            <Info className="sm:col-span-2" label="ที่อยู่ร้าน / ธุรกิจ" value={application.address} />
            <Info className="sm:col-span-2" label="ข้อมูลเพิ่มเติม" value={application.note || "-"} />
            <Info label="ส่งคำขอเมื่อ" value={formatDate(application.created_at)} />
            <Info label="สถานะ" value={MERCHANT_APPLICATION_STATUS_LABEL[application.status] ?? application.status} />
            {application.reviewed_at ? (
              <Info label="ตรวจสอบเมื่อ" value={formatDate(application.reviewed_at)} />
            ) : null}
            {application.reviewer_username ? (
              <Info label="ผู้ตรวจสอบ" value={`@${application.reviewer_username}`} />
            ) : null}
            {application.rejection_reason ? (
              <Info className="sm:col-span-2" label="เหตุผลที่ปฏิเสธ" value={application.rejection_reason} />
            ) : null}
          </div>

          {application.status === "approved" ? (
            <div className="rounded-lg border bg-muted/35 p-3 text-sm">
              {application.merchant_access_enabled ? (
                <p>
                  บัญชีนี้มีสิทธิ์ Merchant แล้ว
                  {application.food_store_id ? (
                    <> · <Link href={`/food/stores/${application.food_store_id}`} className="font-medium underline-offset-4 hover:underline">เปิดหน้าร้านใน Admin</Link></>
                  ) : null}
                </p>
              ) : (
                <p>
                  คำขอได้รับอนุมัติแล้ว แต่ประเภทธุรกิจนี้ยังไม่มี Dashboard เฉพาะที่ provision อัตโนมัติ
                </p>
              )}
            </div>
          ) : application.business_type === "food" ? (
            <div className="rounded-lg border bg-muted/35 p-3 text-sm text-muted-foreground">
              เมื่ออนุมัติ ระบบจะสร้าง Food Store แบบปิดการเผยแพร่ไว้ก่อน และเพิ่มผู้สมัครเป็น Owner อัตโนมัติ
            </div>
          ) : (
            <div className="rounded-lg border bg-muted/35 p-3 text-sm text-muted-foreground">
              ประเภทธุรกิจนี้อนุมัติคำขอได้ แต่ Dashboard เฉพาะประเภทยังไม่ provision อัตโนมัติในเวอร์ชันปัจจุบัน
            </div>
          )}

          {error ? <p role="alert" className="text-sm text-destructive">{error}</p> : null}

          <DialogFooter className="sm:justify-between">
            <div className="flex items-center gap-2">
              {application.merchant_access_enabled ? (
                <a
                  href="https://wynos.online/merchant"
                  target="_blank"
                  rel="noreferrer"
                  className="inline-flex min-h-11 items-center gap-2 text-sm font-medium underline-offset-4 hover:underline"
                >
                  เปิด Merchant <ExternalLink className="size-4" />
                </a>
              ) : null}
            </div>
            <div className="flex flex-col gap-2 sm:flex-row">
              {canReview ? (
                <>
                  <Button type="button" variant="destructive" disabled={pending} onClick={() => setRejectOpen(true)}>
                    ปฏิเสธ
                  </Button>
                  <Button type="button" disabled={pending} aria-busy={pending} onClick={approve}>
                    {pending ? "กำลังอนุมัติ..." : application.business_type === "food" ? "อนุมัติและเปิด Merchant" : "อนุมัติคำขอ"}
                  </Button>
                </>
              ) : !canReviewMerchants && application.status !== "approved" ? (
                <p className="text-sm text-muted-foreground">เฉพาะ Admin เท่านั้นที่อนุมัติหรือปฏิเสธคำขอได้</p>
              ) : null}
            </div>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={rejectOpen} onOpenChange={(next) => {
        setRejectOpen(next);
        if (!next) {
          setReason("");
          setError(null);
        }
      }}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>ปฏิเสธคำขอ Merchant</DialogTitle>
            <DialogDescription>
              ระบุเหตุผลที่ผู้สมัครสามารถนำไปแก้ไขก่อนส่งคำขอใหม่
            </DialogDescription>
          </DialogHeader>
          <Textarea
            value={reason}
            onChange={(event) => setReason(event.target.value)}
            placeholder="เหตุผลที่ปฏิเสธ"
            aria-label="เหตุผลที่ปฏิเสธ"
            disabled={pending}
          />
          {error ? <p role="alert" className="text-sm text-destructive">{error}</p> : null}
          <DialogFooter>
            <Button
              type="button"
              variant="destructive"
              disabled={pending || reason.trim().length === 0}
              aria-busy={pending}
              onClick={reject}
            >
              {pending ? "กำลังปฏิเสธ..." : "ยืนยันปฏิเสธ"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
}

function Info({
  label,
  value,
  className,
}: {
  label: string;
  value: string;
  className?: string;
}) {
  return (
    <div className={`rounded-lg border p-3 ${className ?? ""}`}>
      <p className="text-xs text-muted-foreground">{label}</p>
      <p className="mt-1 whitespace-pre-wrap break-words font-medium">{value}</p>
    </div>
  );
}
