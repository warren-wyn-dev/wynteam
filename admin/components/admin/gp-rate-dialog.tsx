"use client";

import { useMemo, useState, useTransition } from "react";
import { useRouter } from "next/navigation";

import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { cancelGpRate, setGpRate } from "@/lib/admin-gp-actions";
import { adminGpError, bangkokLocalToIso, formatGpRate, parseGpPercent, previewGpSatang } from "@/lib/admin-gp-format";

function baht(satang: number) {
  return `฿${(satang / 100).toLocaleString("th-TH", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

const PREVIEW_BASES = [10000, 25000, 50000];

/**
 * Set a GP rate for one store or the default (super admin only; the RPC
 * re-checks). Two steps: fill in, then confirm a summary of exactly what
 * changes. One idempotency key per dialog opening, so a retried click can
 * never create two rows.
 */
export function GpRateDialog({
  storeId,
  storeName,
  currentRateBp,
  triggerLabel = "แก้ไข GP",
}: {
  /** null = the default for every store without its own rate. */
  storeId: string | null;
  storeName: string;
  currentRateBp: number;
  triggerLabel?: string;
}) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [step, setStep] = useState<"form" | "confirm">("form");
  const [percent, setPercent] = useState("");
  const [startNow, setStartNow] = useState(true);
  const [from, setFrom] = useState("");
  const [to, setTo] = useState("");
  const [reason, setReason] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [key, setKey] = useState("");
  const [pending, startTransition] = useTransition();

  const rateBp = parseGpPercent(percent);
  const fromIso = startNow ? null : bangkokLocalToIso(from);
  const toIso = to ? bangkokLocalToIso(to) : null;
  const formError = useMemo(() => {
    if (rateBp === null) return "ใส่ GP เป็นตัวเลข 0–100 ทศนิยมไม่เกิน 2 ตำแหน่ง";
    if (!startNow && !fromIso) return "เลือกวันเวลาเริ่มมีผล";
    if (to && !toIso) return "วันสิ้นสุดไม่ถูกต้อง";
    if (toIso && fromIso && Date.parse(toIso) <= Date.parse(fromIso)) return "วันสิ้นสุดต้องอยู่หลังวันเริ่ม";
    const trimmed = reason.trim().length;
    if (trimmed < 3 || trimmed > 300) return "ใส่เหตุผล 3–300 ตัวอักษร";
    return null;
  }, [rateBp, startNow, fromIso, to, toIso, reason]);

  function reset() {
    setStep("form");
    setPercent("");
    setStartNow(true);
    setFrom("");
    setTo("");
    setReason("");
    setError(null);
  }

  // Time checks run on click (render must stay pure); the RPC re-checks.
  function goToConfirm() {
    const now = Date.now();
    if (fromIso && Date.parse(fromIso) < now - 60_000) return setError("ตั้ง GP ย้อนหลังไม่ได้ เลือกเวลาตั้งแต่ตอนนี้เป็นต้นไป");
    if (toIso && Date.parse(toIso) <= Date.parse(fromIso ?? new Date(now).toISOString())) return setError("วันสิ้นสุดต้องอยู่หลังวันเริ่ม");
    setError(null);
    setStep("confirm");
  }

  function submit() {
    if (rateBp === null) return;
    setError(null);
    startTransition(async () => {
      try {
        await setGpRate({ storeId, rateBp, effectiveFrom: fromIso, effectiveTo: toIso, reason, idempotencyKey: key });
        setOpen(false);
        reset();
        router.refresh();
      } catch (err) {
        setError(adminGpError(err));
        setStep("form");
      }
    });
  }

  const when = (iso: string | null) =>
    iso ? new Intl.DateTimeFormat("th-TH", { dateStyle: "medium", timeStyle: "short", timeZone: "Asia/Bangkok" }).format(new Date(iso)) : "ทันที";

  return (
    <Dialog
      open={open}
      onOpenChange={(next) => {
        setOpen(next);
        if (next) setKey(crypto.randomUUID());
        else reset();
      }}
    >
      <Button type="button" variant="outline" className="min-h-10" onClick={() => { setKey(crypto.randomUUID()); setOpen(true); }}>
        {triggerLabel}
      </Button>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{step === "form" ? `ตั้ง GP · ${storeName}` : "ยืนยันการเปลี่ยน GP"}</DialogTitle>
          <DialogDescription>
            ตอนนี้ {formatGpRate(currentRateBp)} · คิดจากค่าอาหารหลังส่วนลดของร้าน (ไม่รวมค่าส่ง) · ออเดอร์ที่สั่งไปแล้วใช้อัตราเดิมเสมอ
          </DialogDescription>
        </DialogHeader>

        {step === "form" ? (
          <div className="flex flex-col gap-4">
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="gp-percent">GP ใหม่ (%)</Label>
              <Input id="gp-percent" inputMode="decimal" autoComplete="off" value={percent} onChange={(e) => setPercent(e.target.value)} placeholder="เช่น 15 หรือ 15.5" disabled={pending} />
            </div>

            <fieldset className="flex flex-col gap-2">
              <legend className="text-sm font-medium">เริ่มมีผล (เวลาไทย)</legend>
              <label className="flex min-h-10 items-center gap-2 text-sm">
                <input type="radio" name="gp-start" checked={startNow} onChange={() => setStartNow(true)} disabled={pending} /> ทันที
              </label>
              <label className="flex min-h-10 items-center gap-2 text-sm">
                <input type="radio" name="gp-start" checked={!startNow} onChange={() => setStartNow(false)} disabled={pending} /> กำหนดเวลา
              </label>
              {!startNow ? (
                <Input type="datetime-local" aria-label="วันเวลาเริ่มมีผล" value={from} onChange={(e) => setFrom(e.target.value)} disabled={pending} />
              ) : null}
            </fieldset>

            <div className="flex flex-col gap-1.5">
              <Label htmlFor="gp-to">สิ้นสุด (ไม่บังคับ — สำหรับ GP ชั่วคราว)</Label>
              <Input id="gp-to" type="datetime-local" value={to} onChange={(e) => setTo(e.target.value)} disabled={pending} />
            </div>

            <div className="flex flex-col gap-1.5">
              <Label htmlFor="gp-reason">เหตุผล</Label>
              <Textarea id="gp-reason" value={reason} onChange={(e) => setReason(e.target.value)} maxLength={300} disabled={pending} />
            </div>

            {rateBp !== null ? (
              <div className="rounded-lg border p-3 text-sm">
                <p className="font-medium">ตัวอย่างการคำนวณ</p>
                <ul className="mt-1 space-y-0.5 text-muted-foreground">
                  {PREVIEW_BASES.map((base) => (
                    <li key={base}>
                      ค่าอาหาร {baht(base)} → GP {baht(previewGpSatang(base, rateBp))} · ร้านได้ {baht(base - previewGpSatang(base, rateBp))}
                    </li>
                  ))}
                </ul>
              </div>
            ) : null}

            {error ? <p role="alert" className="text-sm text-destructive">{error}</p> : formError && percent ? <p className="text-sm text-muted-foreground">{formError}</p> : null}
          </div>
        ) : (
          <dl className="grid grid-cols-[auto_1fr] gap-x-4 gap-y-2 text-sm">
            <dt className="text-muted-foreground">ใช้กับ</dt><dd>{storeName}</dd>
            <dt className="text-muted-foreground">GP</dt><dd className="font-semibold">{formatGpRate(currentRateBp)} → {formatGpRate(rateBp ?? 0)}</dd>
            <dt className="text-muted-foreground">เริ่ม</dt><dd>{when(fromIso)}</dd>
            <dt className="text-muted-foreground">สิ้นสุด</dt><dd>{toIso ? when(toIso) : "ไม่กำหนด"}</dd>
            <dt className="text-muted-foreground">เหตุผล</dt><dd className="break-words">{reason.trim()}</dd>
            <dd className="col-span-2 text-muted-foreground">
              Stripe จะหัก GP เป็น application fee จากออเดอร์ที่จ่ายผ่าน Stripe หลังเวลาเริ่มมีผล · ออเดอร์ที่จ่ายด้วยสลิปเข้าบัญชีร้านตรงจะเก็บไม่ได้ · บันทึกลง Audit Log
            </dd>
          </dl>
        )}

        <DialogFooter>
          {step === "form" ? (
            <Button type="button" disabled={Boolean(formError) || pending} onClick={goToConfirm}>ถัดไป</Button>
          ) : (
            <>
              <Button type="button" variant="outline" disabled={pending} onClick={() => setStep("form")}>แก้ไข</Button>
              <Button type="button" disabled={pending} onClick={submit}>{pending ? "กำลังบันทึก…" : "ยืนยันเปลี่ยน GP"}</Button>
            </>
          )}
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

/** Cancel a scheduled rate that has not started yet. */
export function GpCancelButton({ rateId, label }: { rateId: string; label: string }) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [reason, setReason] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  return (
    <Dialog open={open} onOpenChange={(next) => { setOpen(next); if (!next) { setReason(""); setError(null); } }}>
      <Button type="button" variant="outline" className="min-h-9 text-xs" onClick={() => setOpen(true)}>ยกเลิกที่ตั้งไว้</Button>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>ยกเลิก GP ที่ตั้งเวลาไว้</DialogTitle>
          <DialogDescription>{label}</DialogDescription>
        </DialogHeader>
        <Textarea value={reason} onChange={(e) => setReason(e.target.value)} placeholder="เหตุผล" aria-label="เหตุผล" maxLength={300} disabled={pending} />
        {error ? <p role="alert" className="text-sm text-destructive">{error}</p> : null}
        <DialogFooter>
          <Button
            type="button"
            variant="destructive"
            disabled={pending || reason.trim().length < 3}
            onClick={() =>
              startTransition(async () => {
                try {
                  await cancelGpRate({ rateId, reason });
                  setOpen(false);
                  router.refresh();
                } catch (err) {
                  setError(adminGpError(err));
                }
              })
            }
          >
            {pending ? "กำลังยกเลิก…" : "ยืนยันยกเลิก"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
