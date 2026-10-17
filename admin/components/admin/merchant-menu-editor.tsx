"use client";

import { useState, useTransition } from "react";
import Image from "next/image";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import type { AdminMerchantMenuCatalog, AdminMerchantMenuItem } from "@/lib/admin-merchant-menu";
import { menuForm, menuFormError, menuValues, menuErrorMessage } from "@/lib/admin-merchant-menu-form";
import { MerchantMenuOptions } from "@/components/admin/merchant-menu-options";
import { MerchantMenuCategories, type MenuCategoryChange } from "@/components/admin/merchant-menu-categories";
import { MerchantMenuImageUpload } from "@/components/admin/merchant-menu-image-upload";

const buttonClass = "min-h-11 rounded-lg border px-4 text-sm font-medium disabled:opacity-40";
const inputClass = "mt-1 min-h-11 w-full rounded-lg border bg-background px-3 text-sm disabled:opacity-60";

export function AdminMerchantMenuEditor({ original, canEdit }: {
  original: AdminMerchantMenuCatalog; canEdit: boolean;
}) {
  const router = useRouter();
  const [catalog, setCatalog] = useState(original);
  const [storeId, setStoreId] = useState(original.stores[0]?.id ?? "");
  const first = original.items.find(item => item.store_id === original.stores[0]?.id && !item.archived_at);
  const [itemId, setItemId] = useState(first?.id ?? "");
  const [creating, setCreating] = useState(false);
  const [showArchived, setShowArchived] = useState(false);
  const [form, setForm] = useState(() => menuForm(first));
  const [reason, setReason] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState("");
  const [needsReload, setNeedsReload] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [draftRevision, setDraftRevision] = useState(0);
  const [pending, startTransition] = useTransition();
  const busy = pending || uploading;
  const selected = catalog.items.find(item => item.id === itemId && item.store_id === storeId) ?? null;
  const store = catalog.stores.find(item => item.id === storeId);
  const storeItems = catalog.items.filter(item => item.store_id === storeId);
  const visible = storeItems.filter(item => showArchived || !item.archived_at);
  const formError = menuFormError(form);
  const values = formError ? null : menuValues(form, selected);
  const changed = creating || (selected && JSON.stringify(form) !== JSON.stringify(menuForm(selected)));
  const reasonValid = reason.trim().length >= 5 && reason.trim().length <= 300;
  const imageUploadDisabled = !canEdit || pending || needsReload || Boolean(selected?.archived_at);
  const editingDisabled = imageUploadDisabled || uploading;
  const imagePaths = [...new Set([
    ...catalog.images.filter(image => image.store_id === storeId).map(image => image.path),
    ...storeItems.flatMap(item => item.image_path ? [item.image_path] : []),
    ...(form.image_path ? [form.image_path] : []),
  ])];
  const imageUrl = form.image_path ? createClient().storage.from("food-public").getPublicUrl(form.image_path).data.publicUrl : null;

  function reset(item?: AdminMerchantMenuItem, create = false) {
    setDraftRevision(value => value + 1);
    setItemId(item?.id ?? ""); setCreating(create); setForm(menuForm(item));
    setError(null); setSuccess(""); setReason("");
  }
  function discardAllowed() {
    return !busy && (!changed || window.confirm("มีข้อมูลที่ยังไม่บันทึก ต้องการละทิ้งการแก้ไขหรือไม่?"));
  }
  function chooseStore(id: string) {
    if (!discardAllowed()) return;
    setStoreId(id); reset(catalog.items.find(item => item.store_id === id && (showArchived || !item.archived_at)));
  }
  async function reload(preferredId = itemId) {
    const { data, error: readError } = await createClient().rpc("admin_merchant_menu_catalog", { p_store_id: null })
      .abortSignal(AbortSignal.timeout(15_000));
    if (readError) throw readError;
    if (!data || !Array.isArray(data.stores) || !Array.isArray(data.items) || !Array.isArray(data.images)) throw new Error("invalid_menu_catalog");
    const next = data as AdminMerchantMenuCatalog;
    setCatalog(next);
    const item = next.items.find(item => item.id === preferredId && item.store_id === storeId)
      ?? next.items.find(item => item.store_id === storeId && (showArchived || !item.archived_at));
    if (item?.archived_at) setShowArchived(true);
    setNeedsReload(false);
    reset(item);
    router.refresh();
  }
  function mutate(message: string, operation: () => Promise<{ data: unknown; error: unknown }>, preferredId?: string) {
    if (!canEdit || busy || needsReload || !window.confirm(message)) return;
    setError(null); setSuccess("");
    startTransition(async () => {
      let saved = false;
      try {
        const result = await operation();
        if (result.error) throw result.error;
        saved = true;
        setNeedsReload(true);
        const resultId = result.data && typeof result.data === "object" && "id" in result.data ? String(result.data.id) : undefined;
        await reload(preferredId ?? resultId ?? itemId);
        setSuccess("บันทึกเรียบร้อย และโหลดข้อมูลล่าสุดแล้ว");
      } catch (writeError) {
        const code = writeError && typeof writeError === "object" && "code" in writeError ? String(writeError.code) : "";
        const uncertainCreate = creating && !saved && code !== "P0001" && !/^22|^23|^42/.test(code);
        if (uncertainCreate) setNeedsReload(true);
        setError(saved ? "บันทึกสำเร็จ แต่โหลดข้อมูลล่าสุดไม่สำเร็จ กรุณากดโหลดข้อมูลล่าสุดก่อนทำรายการต่อ"
          : uncertainCreate ? "ยังยืนยันผลการเพิ่มเมนูไม่ได้ กรุณาโหลดข้อมูลล่าสุดและตรวจรายการก่อนเพิ่มอีกครั้ง" : menuErrorMessage(writeError));
      }
    });
  }
  function save() {
    if (!store || !canEdit || busy || !values || !reasonValid || !changed || selected?.archived_at) return;
    const proposed = values;
    mutate(`ยืนยัน${creating ? "เพิ่ม" : "แก้ไข"}เมนู “${proposed.name}” ของร้าน “${store.name}” ราคา ${proposed.price} บาท? ข้อมูลนี้มีผลกับการสั่งซื้อใหม่`, async () =>
      await createClient().rpc("admin_save_merchant_menu_item", {
        p_item_id: creating ? null : selected?.id,
        p_store_id: storeId, p_expected_updated_at: creating ? null : selected?.updated_at,
        p_values: proposed, p_reason: reason.trim(),
      }).abortSignal(AbortSignal.timeout(20_000)));
  }
  function archive() {
    if (!selected || !reasonValid) return;
    const item = selected;
    mutate(item.archived_at
      ? `ยืนยันกู้คืนเมนู “${item.name}”? เมนูจะยังปิดขายจนกว่าจะเปิดขายอีกครั้ง`
      : `ยืนยันเก็บเมนู “${item.name}”? ลูกค้าจะสั่งเมนูนี้ไม่ได้ และประวัติออเดอร์ยังอยู่`, async () =>
      await createClient().rpc("admin_set_merchant_menu_item_archived", {
        p_item_id: item.id, p_expected_updated_at: item.updated_at,
        p_archived: !item.archived_at, p_reason: reason.trim(),
      }).abortSignal(AbortSignal.timeout(20_000)), item.id);
  }
  function saveCategories(change: MenuCategoryChange) {
    if (!store || !discardAllowed()) return;
    mutate(`ยืนยันแก้หมวดหมู่ของร้าน “${store.name}”? เมนูในหมวดที่เปลี่ยนชื่อจะย้ายชื่อหมวดพร้อมกัน`, async () =>
      await createClient().rpc("admin_save_merchant_menu_categories", {
        p_store_id: storeId, p_expected_updated_at: store.updated_at,
        p_expected_items: Object.fromEntries(storeItems.map(item => [item.id, item.updated_at])),
        p_category_order: change.order, p_renames: change.renames, p_reason: change.reason,
      }).abortSignal(AbortSignal.timeout(20_000)));
  }

  return <section className="space-y-5 rounded-2xl border bg-background p-4 sm:p-6" aria-busy={busy}>
    <div className="flex flex-wrap items-end gap-3">
      <label className="min-w-48 flex-1 text-sm font-medium">เลือกร้าน
        <select className={inputClass} disabled={busy} value={storeId} onChange={event => chooseStore(event.target.value)}>
          {!catalog.stores.length ? <option value="">ยังไม่มีร้าน</option> : null}
          {catalog.stores.map(item => <option key={item.id} value={item.id}>{item.name}</option>)}
        </select>
      </label>
      {canEdit ? <button type="button" className={buttonClass} disabled={busy || needsReload || !store}
        onClick={() => { if (discardAllowed()) reset(undefined, true); }}>เพิ่มเมนูใหม่</button> : null}
      <button type="button" className={buttonClass} disabled={busy} onClick={() => {
        if (!discardAllowed()) return;
        startTransition(async () => { try { setError(null); await reload(); } catch (readError) { setError(menuErrorMessage(readError)); } });
      }}>โหลดข้อมูลล่าสุด</button>
    </div>
    {store ? <MerchantMenuCategories key={`${store.id}:${store.updated_at}`} store={store} items={storeItems}
      canEdit={canEdit && !needsReload} pending={busy} onSave={saveCategories} /> : null}
    <div className="grid items-end gap-3 sm:grid-cols-[1fr_auto]">
      <label className="text-sm font-medium">เลือกเมนู
        <select className={inputClass} disabled={busy} value={creating ? "" : itemId} onChange={event => {
          if (discardAllowed()) reset(visible.find(item => item.id === event.target.value));
        }}>
          <option value="">{creating ? "กำลังเพิ่มเมนูใหม่" : "เลือกเมนู"}</option>
          {visible.map(item => <option key={item.id} value={item.id}>{item.name} — {item.category}{item.archived_at ? " (เก็บแล้ว)" : item.is_available ? "" : " (ปิดขาย)"}</option>)}
        </select>
      </label>
      <label className="flex min-h-11 items-center gap-2 text-sm">
        <input type="checkbox" checked={showArchived} disabled={busy} onChange={event => {
          if (!event.target.checked && selected?.archived_at && !discardAllowed()) return;
          setShowArchived(event.target.checked);
          if (!event.target.checked && selected?.archived_at) reset(storeItems.find(item => !item.archived_at));
        }} />แสดงเมนูที่เก็บแล้ว
      </label>
    </div>
    {creating || selected ? <>
      <div>
        <h2 className="text-lg font-semibold">{creating ? "เพิ่มเมนูใหม่" : selected?.name}</h2>
        {selected?.archived_at ? <p className="mt-1 text-sm text-muted-foreground">เมนูนี้เก็บไว้แล้ว กู้คืนก่อนแก้ไข เมนูที่กู้คืนจะยังปิดขาย</p> : null}
      </div>
      <fieldset disabled={editingDisabled} className="space-y-4">
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label="ชื่อเมนู" value={form.name} onChange={value => setForm({ ...form, name: value })} maxLength={160} />
          <label className="text-sm font-medium">หมวดหมู่
            <input className={inputClass} value={form.category} maxLength={60} list="merchant-menu-categories"
              onChange={event => setForm({ ...form, category: event.target.value })} />
            <datalist id="merchant-menu-categories">{[...new Set([...(store?.menu_category_order ?? []), ...storeItems.map(item => item.category)])]
              .map(name => <option key={name} value={name} />)}</datalist>
          </label>
          <Field label="ราคา (บาท)" value={form.price} onChange={value => setForm({ ...form, price: value })} type="number" min={0} max={100000} step="0.01" />
          <Field label="สต็อกสูงสุดต่อวัน (เว้นว่าง = ไม่จำกัด)" value={form.daily_stock_limit} onChange={value => setForm({ ...form, daily_stock_limit: value })} type="number" min={1} max={9999} step="1" />
        </div>
        <label className="block text-sm font-medium">รายละเอียดอาหาร
          <textarea className="mt-1 w-full rounded-lg border bg-background p-3 text-sm" value={form.description} rows={3} maxLength={1000}
            onChange={event => setForm({ ...form, description: event.target.value })} />
        </label>
        <div className="grid items-center gap-4 sm:grid-cols-2">
          <label className="flex min-h-11 items-center gap-2 text-sm font-medium"><input type="checkbox" checked={form.is_available}
            onChange={event => setForm({ ...form, is_available: event.target.checked })} />เปิดขายเมนูนี้</label>
          <Field label="หยุดขายจนถึง (เวลาไทย เว้นว่าง = ไม่หยุด)" type="datetime-local" value={form.sold_out_until}
            onChange={value => setForm({ ...form, sold_out_until: value })} />
        </div>
      </fieldset>
        <fieldset disabled={imageUploadDisabled} className="space-y-3 rounded-xl border p-4">
          <legend className="px-1 text-sm font-semibold">รูปเมนู</legend>
          <p className="text-xs text-muted-foreground">เลือกรูปที่ร้านเคยอัปโหลดไว้ หรือเอารูปออกจากเมนู การเอารูปออกยังเก็บไฟล์เดิมไว้</p>
          <label className="block text-sm">เลือกรูปของร้านนี้
            <select className={inputClass} disabled={uploading} value={form.image_path} onChange={event => setForm({ ...form, image_path: event.target.value })}>
              <option value="">ไม่มีรูป</option>
              {imagePaths.map((path, index) => <option key={path} value={path}>รูปที่ {index + 1}{path === selected?.image_path ? " (รูปปัจจุบัน)" : ""}</option>)}
            </select>
          </label>
          {imageUrl ? <div className="flex flex-wrap items-end gap-3">
            <Image unoptimized src={imageUrl} width={240} height={180} className="aspect-[4/3] max-w-full rounded-xl border object-cover" alt={`ตัวอย่างรูปเมนู ${form.name}`} />
            <button type="button" disabled={uploading} className={buttonClass} onClick={() => setForm({ ...form, image_path: "" })}>เอารูปออก</button>
          </div> : <p className="text-sm text-muted-foreground">ยังไม่มีรูปเมนู</p>}
          {canEdit && !selected?.archived_at ? <MerchantMenuImageUpload key={`${storeId}:${creating ? "new" : itemId}:${draftRevision}`}
            storeId={storeId} disabled={imageUploadDisabled} onBusyChange={setUploading}
            onUploaded={path => setForm(current => ({ ...current, image_path: path }))} /> : null}
        </fieldset>
      <fieldset disabled={editingDisabled}>
        <MerchantMenuOptions value={form.options} onChange={options => setForm({ ...form, options })} disabled={editingDisabled} />
      </fieldset>
      {canEdit ? <>
        <label className="block text-sm font-medium">เหตุผลการเปลี่ยนแปลง (5–300 ตัวอักษร)
          <textarea className="mt-1 w-full rounded-lg border bg-background p-3 text-sm" rows={2} maxLength={300} disabled={busy}
            value={reason} onChange={event => setReason(event.target.value)} />
        </label>
        {formError && changed && !selected?.archived_at ? <p role="alert" className="text-sm text-red-600">{formError}</p> : null}
        <div className="flex flex-wrap gap-2">
          {!selected?.archived_at ? <button type="button" onClick={save}
            className="min-h-11 rounded-lg bg-foreground px-5 text-sm font-semibold text-background disabled:opacity-40"
            disabled={busy || needsReload || Boolean(formError) || !changed || !reasonValid}>{pending ? "กำลังบันทึก…" : creating ? "ยืนยันเพิ่มเมนู" : "ยืนยันบันทึกเมนู"}</button> : null}
          {!creating && selected ? <button type="button" className={buttonClass} onClick={archive}
            disabled={busy || needsReload || !reasonValid || Boolean(changed)}>{selected.archived_at ? "กู้คืนเมนู (ยังปิดขาย)" : "เก็บเมนู"}</button> : null}
          {changed && !creating ? <button type="button" className={buttonClass} disabled={busy} onClick={() => {
            if (discardAllowed()) reset(selected ?? undefined);
          }}>ยกเลิกการแก้ไข</button> : null}
        </div>
      </> : <p className="text-sm text-muted-foreground">ดูข้อมูลได้เท่านั้น ต้องมีสิทธิ์ merchant:edit เพื่อบันทึก</p>}
    </> : <p className="rounded-xl border border-dashed p-5 text-sm text-muted-foreground">ยังไม่มีเมนูในรายการนี้{canEdit ? " เริ่มได้ที่ “เพิ่มเมนูใหม่”" : ""}</p>}
    {pending ? <p role="status" className="text-sm">กำลังดำเนินการ กรุณารอสักครู่…</p> : null}
    {error ? <p role="alert" className="text-sm text-red-600">{error}</p> : null}
    {success ? <p role="status" className="text-sm">{success}</p> : null}
    <p className="text-xs leading-relaxed text-muted-foreground">ราคา ตัวเลือก และสต็อกมีผลกับการสั่งซื้อใหม่ ออเดอร์เดิมเก็บชื่อ ราคา และตัวเลือก ณ เวลาสั่งซื้อ ทุกการเปลี่ยนแปลงบันทึกเหตุผลและประวัติก่อน–หลัง</p>
  </section>;
}

function Field({ label, value, onChange, type = "text", maxLength, min, max, step }: {
  label: string; value: string; onChange: (value: string) => void;
  type?: "text" | "number" | "datetime-local"; maxLength?: number; min?: number; max?: number; step?: string;
}) {
  return <label className="block text-sm font-medium">{label}
    <input className={inputClass} type={type} value={value} maxLength={maxLength} min={min} max={max} step={step}
      onChange={event => onChange(event.target.value)} />
  </label>;
}
