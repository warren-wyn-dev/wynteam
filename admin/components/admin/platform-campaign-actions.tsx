"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Pencil, Plus, Send } from "lucide-react";

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
import { platformCampaignError, savePlatformCampaign, settlePlatformStore, type PlatformCampaignInput } from "@/lib/admin-food-actions";
import type { AdminPlatformCampaign } from "@/lib/admin-platform-campaigns";

function toLocalInput(value: string | null | undefined) {
  if (!value) return "";
  const date = new Date(value);
  const local = new Date(date.getTime() - date.getTimezoneOffset() * 60_000);
  return local.toISOString().slice(0, 16);
}

const fieldClass = "h-11 w-full rounded-md border bg-background px-3 text-sm";

/** WYN-206: create or edit a WYNOS campaign, including who funds the discount. */
export function PlatformCampaignFormButton({ campaign }: { campaign?: AdminPlatformCampaign }) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();
  const [form, setForm] = useState(() => ({
    name: campaign?.name ?? "",
    description: campaign?.description ?? "",
    campaignType: campaign?.campaign_type ?? "percentage",
    discountValue: String(campaign?.discount_value ?? 10),
    minSubtotal: String(campaign?.min_subtotal ?? 0),
    maxDiscount: campaign?.max_discount != null ? String(campaign.max_discount) : "",
    startsAt: toLocalInput(campaign?.starts_at ?? new Date().toISOString()),
    endsAt: toLocalInput(campaign?.ends_at),
    usageLimitPerStore: campaign?.usage_limit_per_store != null ? String(campaign.usage_limit_per_store) : "",
    platformSharePercent: String(campaign?.platform_share_percent ?? 50),
    joinOpen: campaign?.join_open ?? true,
    isActive: campaign?.is_active ?? true,
  }));
  const set = <K extends keyof typeof form>(key: K, value: (typeof form)[K]) => setForm((current) => ({ ...current, [key]: value }));
  const share = Math.min(100, Math.max(0, Number(form.platformSharePercent) || 0));

  function submit() {
    setError(null);
    const input: PlatformCampaignInput = {
      id: campaign?.id ?? null,
      name: form.name,
      description: form.description,
      campaignType: form.campaignType as PlatformCampaignInput["campaignType"],
      discountValue: form.campaignType === "free_delivery" ? 0 : Number(form.discountValue),
      minSubtotal: Number(form.minSubtotal) || 0,
      maxDiscount: form.campaignType === "percentage" && form.maxDiscount ? Number(form.maxDiscount) : null,
      startsAt: new Date(form.startsAt || Date.now()).toISOString(),
      endsAt: form.endsAt ? new Date(form.endsAt).toISOString() : null,
      usageLimitPerStore: form.usageLimitPerStore ? Number(form.usageLimitPerStore) : null,
      platformSharePercent: Number(form.platformSharePercent),
      joinOpen: form.joinOpen,
      isActive: form.isActive,
    };
    startTransition(async () => {
      try {
        await savePlatformCampaign(input);
        setOpen(false);
        router.refresh();
      } catch (err) {
        setError(platformCampaignError(err, "บันทึกแคมเปญไม่สำเร็จ"));
      }
    });
  }

  return (
    <>
      {campaign ? (
        <Button variant="outline" size="sm" className="min-h-9 gap-1" onClick={() => setOpen(true)}><Pencil className="size-4" />แก้ไข</Button>
      ) : (
        <Button className="min-h-11 gap-2" onClick={() => setOpen(true)}><Plus className="size-4" />สร้างแคมเปญ</Button>
      )}
      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent className="max-h-[90dvh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>{campaign ? "แก้ไขแคมเปญ" : "สร้างแคมเปญ WYNOS"}</DialogTitle>
            <DialogDescription>ร้านที่เข้าร่วมแล้วจะใช้เงื่อนไขใหม่กับออเดอร์ถัดไปทันที ออเดอร์ที่สั่งไปแล้วใช้สัดส่วนเดิม</DialogDescription>
          </DialogHeader>
          <div className="grid gap-3 text-sm">
            <label className="grid gap-1"><span>ชื่อแคมเปญ</span><input className={fieldClass} value={form.name} maxLength={80} onChange={(e) => set("name", e.target.value)} placeholder="เช่น ศุกร์ลดแรง" /></label>
            <label className="grid gap-1"><span>รายละเอียดสำหรับร้าน (ไม่บังคับ)</span><Textarea value={form.description} maxLength={300} onChange={(e) => set("description", e.target.value)} /></label>
            <div className="grid grid-cols-2 gap-3">
              <label className="grid gap-1"><span>ประเภทส่วนลด</span>
                <select className={fieldClass} value={form.campaignType} onChange={(e) => set("campaignType", e.target.value as typeof form.campaignType)}>
                  <option value="percentage">ลดเป็น %</option>
                  <option value="fixed">ลดเป็นบาท</option>
                  <option value="free_delivery">ส่งฟรี</option>
                </select>
              </label>
              {form.campaignType !== "free_delivery" ? (
                <label className="grid gap-1"><span>{form.campaignType === "percentage" ? "ลดกี่ %" : "ลดกี่บาท"}</span><input className={fieldClass} inputMode="decimal" value={form.discountValue} onChange={(e) => set("discountValue", e.target.value)} /></label>
              ) : <span />}
              <label className="grid gap-1"><span>ยอดขั้นต่ำ (บาท)</span><input className={fieldClass} inputMode="decimal" value={form.minSubtotal} onChange={(e) => set("minSubtotal", e.target.value)} /></label>
              {form.campaignType === "percentage" ? (
                <label className="grid gap-1"><span>ลดสูงสุด (บาท)</span><input className={fieldClass} inputMode="decimal" value={form.maxDiscount} onChange={(e) => set("maxDiscount", e.target.value)} placeholder="ไม่จำกัด" /></label>
              ) : <span />}
              <label className="grid gap-1"><span>เริ่ม</span><input type="datetime-local" className={fieldClass} value={form.startsAt} onChange={(e) => set("startsAt", e.target.value)} /></label>
              <label className="grid gap-1"><span>จบ (ไม่บังคับ)</span><input type="datetime-local" className={fieldClass} value={form.endsAt} onChange={(e) => set("endsAt", e.target.value)} /></label>
              <label className="grid gap-1"><span>จำกัดครั้งต่อร้าน</span><input className={fieldClass} inputMode="numeric" value={form.usageLimitPerStore} onChange={(e) => set("usageLimitPerStore", e.target.value)} placeholder="ไม่จำกัด" /></label>
            </div>
            <label className="grid gap-1">
              <span>WYNOS ออกส่วนลดกี่ % (ที่เหลือร้านออก)</span>
              <input type="range" min={0} max={100} step={5} value={share} onChange={(e) => set("platformSharePercent", e.target.value)} />
              <span className="text-muted-foreground">{`WYNOS ออก ${share}% · ร้านออก ${100 - share}%`}</span>
            </label>
            <label className="flex min-h-11 items-center gap-2"><input type="checkbox" checked={form.joinOpen} onChange={(e) => set("joinOpen", e.target.checked)} />เปิดให้ร้านเข้าร่วม</label>
            <label className="flex min-h-11 items-center gap-2"><input type="checkbox" checked={form.isActive} onChange={(e) => set("isActive", e.target.checked)} />แคมเปญทำงานอยู่ (ปิดเพื่อหยุดส่วนลดทุกร้าน)</label>
          </div>
          {error ? <p role="alert" className="text-sm text-destructive">{error}</p> : null}
          <DialogFooter>
            <Button variant="outline" onClick={() => setOpen(false)} disabled={pending}>ยกเลิก</Button>
            <Button onClick={submit} disabled={pending || form.name.trim().length < 2}>{pending ? "กำลังบันทึก…" : "บันทึก"}</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
}

/** WYN-206: record a transfer of what WYNOS owes a store. */
export function PlatformSettleButton({ storeId, storeName, owed, owedAmount, owedOrders }: { storeId: string; storeName: string; owed: string; owedAmount: number; owedOrders: number }) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [reference, setReference] = useState("");
  const [note, setNote] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  function submit() {
    setError(null);
    startTransition(async () => {
      try {
        await settlePlatformStore({ storeId, reference, note, expectedAmount: owedAmount, expectedCount: owedOrders });
        setOpen(false);
        setReference("");
        setNote("");
        router.refresh();
      } catch (err) {
        setError(platformCampaignError(err, "บันทึกการโอนไม่สำเร็จ"));
      }
    });
  }

  return (
    <>
      <Button size="sm" className="min-h-9 gap-1" onClick={() => setOpen(true)}><Send className="size-4" />บันทึกว่าโอนแล้ว</Button>
      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{`โอนคืนร้าน ${storeName}`}</DialogTitle>
            <DialogDescription>{`โอน ${owed} (${owedOrders} ออเดอร์) ให้ร้านก่อน แล้วใส่เลขอ้างอิงการโอน ระบบจะปิดยอดเฉพาะเมื่อยอดยังตรงกับที่แสดงนี้ และแจ้งเจ้าของร้าน`}</DialogDescription>
          </DialogHeader>
          <label className="grid gap-1 text-sm"><span>เลขอ้างอิงการโอน</span><input className={fieldClass} value={reference} maxLength={120} onChange={(e) => setReference(e.target.value)} /></label>
          <label className="grid gap-1 text-sm"><span>หมายเหตุ (ไม่บังคับ)</span><Textarea value={note} maxLength={300} onChange={(e) => setNote(e.target.value)} /></label>
          {error ? <p role="alert" className="text-sm text-destructive">{error}</p> : null}
          <DialogFooter>
            <Button variant="outline" onClick={() => setOpen(false)} disabled={pending}>ยกเลิก</Button>
            <Button onClick={submit} disabled={pending || !reference.trim()}>{pending ? "กำลังบันทึก…" : "ยืนยันว่าโอนแล้ว"}</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
}
