"use client";

import { useMemo, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import type { AdminMerchantMenuItem } from "@/lib/admin-merchant-menu";

type EditForm = {
  name: string; category: string; description: string; price: string;
  is_available: boolean; daily_stock_limit: string;
};
function toForm(x: AdminMerchantMenuItem): EditForm {
  return {
    name: x.name, category: x.category, description: x.description ?? "",
    price: String(x.price), is_available: x.is_available,
    daily_stock_limit: x.daily_stock_limit === null ? "" : String(x.daily_stock_limit),
  };
}
function oldValues(x: AdminMerchantMenuItem) {
  return {
    name: x.name, category: x.category, description: x.description,
    price: Number(x.price), is_available: x.is_available, daily_stock_limit: x.daily_stock_limit,
  };
}

export function AdminMerchantMenuEditor({
  original,
  canEdit,
}: {original: AdminMerchantMenuItem[]; canEdit: boolean}) {
  const router = useRouter();
  const [items, setItems] = useState(original);
  const [storeId, setStoreId] = useState<string>("");
  const [itemId, setItemId] = useState(original[0]?.id ?? "");
  const selected = items.find(x => x.id === itemId) ?? null;
  const [form, setForm] = useState<EditForm>(original[0] ? toForm(original[0]) : {
    name: "", category: "", description: "", price: "", is_available: true, daily_stock_limit: "",
  });
  const [reason, setReason] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState("");
  const [pending, startTransition] = useTransition();
  const stores = useMemo(() => [...new Map(items.map(x => [x.store_id, {id:x.store_id,name:x.store_name}])).values()], [items]);
  const filtered = storeId ? items.filter(x => x.store_id === storeId) : items;
  const proposed = {
    name: form.name.trim(),
    category: form.category.trim(),
    description: form.description.trim() || null,
    price: form.price.trim() === "" ? NaN : Number(form.price),
    is_available: form.is_available,
    daily_stock_limit: form.daily_stock_limit.trim() === "" ? null : Number(form.daily_stock_limit),
  };
  const originalValues = selected ? oldValues(selected) : null;
  const changed = selected ? JSON.stringify(proposed) !== JSON.stringify(originalValues) : false;
  const invalid = !proposed.name || proposed.name.length>160
    || !proposed.category || proposed.category.length>60
    || (proposed.description?.length ?? 0)>1000
    || !Number.isFinite(proposed.price) || proposed.price<0 || proposed.price>100000
    || (proposed.daily_stock_limit !== null && (!Number.isInteger(proposed.daily_stock_limit)
      || proposed.daily_stock_limit < 1 || proposed.daily_stock_limit > 9999));
  function chooseItem(id: string) {
    setItemId(id);
    const item=items.find(x=>x.id===id);
    if(item)setForm(toForm(item));
    setError(null);setSuccess("");setReason("");
  }
  function chooseStore(id: string) {
    setStoreId(id);
    const target = items.find(x=> !id || x.store_id===id);
    chooseItem(target?.id??"");
  }
  async function reload() {
    const {data,error:err}=await createClient().rpc("admin_merchant_menu_items",{p_store_id:null});
    if(err)throw err;
    const rows=Array.isArray(data)?data as AdminMerchantMenuItem[]:[];
    setItems(rows);
    const item=rows.find(x=>x.id===itemId);
    if(item)setForm(toForm(item));
    router.refresh();
  }
  function save() {
    setError(null);setSuccess("");
    if(!canEdit || !selected || invalid || !changed || reason.trim().length<5) {
      setError("กรอกข้อมูลที่ต้องการเปลี่ยนให้ถูกต้อง และระบุเหตุผลอย่างน้อย 5 ตัวอักษร");
      return;
    }
    if(!window.confirm(`ยืนยันแก้เมนู “${selected.name}” ในร้าน “${selected.store_name}”? การเปลี่ยนแปลงอาจส่งผลต่อการสั่งซื้อใหม่ทันที`))return;
    startTransition(async () => {
      try{
        const {error:writeError}=await createClient().rpc("admin_update_merchant_menu_item",{
          p_item_id:selected.id,
          p_expected:oldValues(selected),
          p_name:proposed.name,
          p_category:proposed.category,
          p_description:proposed.description,
          p_price:proposed.price,
          p_is_available:proposed.is_available,
          p_daily_stock_limit:proposed.daily_stock_limit,
          p_reason:reason.trim(),
        });
        if(writeError)throw writeError;
        await reload();setReason("");setSuccess("บันทึกเมนูลงระบบจริงและโหลดข้อมูลล่าสุดแล้ว");
      }catch(err) {
        const msg=err instanceof Error?err.message:String(err);
        setError(msg.includes("item changed")?"เมนูถูกแก้ไขโดยผู้อื่น กรุณาโหลดข้อมูลล่าสุด":msg.includes("Not authorized")?
          "ไม่มีสิทธิ์แก้ไข Merchant":"บันทึกไม่สำเร็จ: "+msg);
      }
    });
  }
  return (
    <section className="space-y-5 rounded-2xl border bg-background p-4 sm:p-6">
      <div>
        <h2 className="text-lg font-semibold">จัดการเมนูอาหารทุกร้าน</h2>
        <p className="mt-1 text-sm text-muted-foreground">
          แก้ชื่อ ราคา หมวดหมู่ รายละเอียด จำนวนจำกัดต่อวัน และสถานะเปิดขายจาก WYNOS Admin
          โดยไม่แก้รูปภาพหรือตัวเลือกเสริมของเมนูในส่วนนี้
        </p>
      </div>
      <div className="grid gap-3 sm:grid-cols-2">
        <label className="block text-sm font-medium">
          เลือกร้าน
          <select value={storeId} onChange={e=>chooseStore(e.target.value)} className="mt-1 block h-11 w-full rounded-lg border bg-background px-3 text-sm">
            <option value="">ทุกร้าน</option>
            {stores.map(s=><option key={s.id} value={s.id}>{s.name}</option>)}
          </select>
        </label>
        <label className="block text-sm font-medium">
          เลือกเมนู
          <select value={filtered.some(x=>x.id===itemId)?itemId:""} onChange={e=>chooseItem(e.target.value)}
            className="mt-1 block h-11 w-full rounded-lg border bg-background px-3 text-sm">
            {filtered.length===0?<option value="">ไม่พบเมนู</option>:null}
            {filtered.map(item=><option key={item.id} value={item.id}>{item.name} — {item.store_name}</option>)}
          </select>
        </label>
      </div>
      {selected ? (
        <>
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="ชื่อเมนู" value={form.name} onChange={v=>setForm(x=>({...x,name:v}))} maxLength={160} disabled={!canEdit||pending}/>
            <Field label="หมวดหมู่" value={form.category} onChange={v=>setForm(x=>({...x,category:v}))} maxLength={60} disabled={!canEdit||pending}/>
            <Field label="ราคา (บาท)" value={form.price} onChange={v=>setForm(x=>({...x,price:v}))} type="number" disabled={!canEdit||pending}/>
            <Field label="สต็อกสูงสุดต่อวัน (เว้นว่าง = ไม่จำกัด)" value={form.daily_stock_limit} onChange={v=>setForm(x=>({...x,daily_stock_limit:v}))} type="number" disabled={!canEdit||pending}/>
          </div>
          <label className="block text-sm font-medium">
            รายละเอียดอาหาร
            <textarea maxLength={1000} rows={3} value={form.description} disabled={!canEdit||pending}
              onChange={e=>setForm(x=>({...x,description:e.target.value}))}
              className="mt-1 block w-full rounded-lg border bg-background p-3 text-sm disabled:opacity-60"/>
          </label>
          <label className="flex items-center gap-3 text-sm font-medium">
            <input type="checkbox" checked={form.is_available} disabled={!canEdit||pending}
              onChange={e=>setForm(x=>({...x,is_available:e.target.checked}))}
              className="size-4 rounded border"/>
            เปิดขายเมนูนี้
          </label>
          {selected.sold_out_until ? <p className="text-xs text-muted-foreground">มีเวลาหยุดขายชั่วคราวแยกอยู่: {new Intl.DateTimeFormat("th-TH",{timeZone:"Asia/Bangkok",dateStyle:"medium",timeStyle:"short"}).format(new Date(selected.sold_out_until))} การเปิดขายอาจยังถูกจำกัดตามเวลานี้</p>:null}
          {canEdit ? <>
            <label className="block text-sm font-medium">
              เหตุผลการแก้ไข (บังคับ)
              <textarea rows={2} maxLength={300} value={reason} disabled={pending}
                onChange={e=>setReason(e.target.value)} placeholder="เช่น แก้ราคาตามเอกสารที่ร้านแจ้ง"
                className="mt-1 block w-full rounded-lg border bg-background p-3 text-sm"/>
            </label>
            <div className="flex flex-wrap gap-2">
              <button type="button" onClick={save} disabled={pending||invalid||!changed||reason.trim().length<5}
                className="min-h-11 rounded-lg bg-foreground px-5 text-sm font-semibold text-background disabled:opacity-40">
                {pending?"กำลังบันทึก…":"ยืนยันบันทึกเมนูจริง"}
              </button>
              <button type="button" disabled={pending} onClick={()=>startTransition(async()=>{try {setError(null);await reload();setSuccess("");}catch(err){setError("โหลดใหม่ไม่สำเร็จ: "+String(err));}})}
                className="min-h-11 rounded-lg border px-5 text-sm font-medium">โหลดข้อมูลล่าสุด</button>
            </div>
          </>:<p className="text-xs text-muted-foreground">ดูข้อมูลได้เท่านั้น ต้องมี merchant:edit เพื่อบันทึก</p>}
          {error?<p role="alert" className="text-sm text-red-600">{error}</p>:null}
          {success?<p role="status" className="text-sm font-medium">{success}</p>:null}
        </>
      ):<p className="text-sm text-muted-foreground">ยังไม่มีเมนูให้แสดง</p>}
      <p className="text-xs leading-relaxed text-muted-foreground">
        การเปลี่ยนราคาหรือเปิด/ปิดเมนูมีผลกับคำสั่งซื้อใหม่ ไม่แก้ยอดออเดอร์เดิม
        ผู้ใช้ต้องมีสิทธิ์ merchant:edit และการเปลี่ยนแปลงบันทึกใน Audit Log พร้อมค่าก่อน–หลัง
      </p>
    </section>
  );
}
function Field({label,value,onChange,maxLength,type="text",disabled}:{
  label:string;value:string;onChange:(v:string)=>void;maxLength?:number;type?:"text"|"number";disabled:boolean;
}) {
  return <label className="block text-sm font-medium">
    {label}
    <input type={type} value={value} onChange={e=>onChange(e.target.value)}
      min={type==="number"?0:undefined} step={type==="number"?"0.01":undefined} maxLength={maxLength} disabled={disabled}
      className="mt-1 block h-11 w-full rounded-lg border bg-background px-3 text-sm disabled:opacity-60"/>
  </label>;
}
