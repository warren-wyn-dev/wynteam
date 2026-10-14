"use client";
import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import type { AdminFeaturedStore, AdminStoreOption } from "@/lib/admin-food-featured";

function datetimeLocal(iso:string):string{
 const d=new Date(iso);
 return new Date(d.getTime()-d.getTimezoneOffset()*60000).toISOString().slice(0,16);
}
function defaultStart():string{return datetimeLocal(new Date().toISOString());}
export function FoodFeaturedManager({
 initial,stores,canEdit,
}:{initial:AdminFeaturedStore[];stores:AdminStoreOption[];canEdit:boolean}){
 const router=useRouter();
 const [rows,setRows]=useState(initial);
 const [storeId,setStoreId]=useState(stores[0]?.id??"");
 const first=initial.find(r=>r.store_id===stores[0]?.id);
 const [priority,setPriority]=useState(String(first?.priority??10));
 const [active,setActive]=useState(first?.active??false);
 const [startsAt,setStartsAt]=useState(()=>first?datetimeLocal(first.starts_at):defaultStart());
 const [endsAt,setEndsAt]=useState(()=>first?.ends_at?datetimeLocal(first.ends_at):"");
 const [reason,setReason]=useState("");
 const [pending,startTransition]=useTransition();
 const [error,setError]=useState<string|null>(null);
 const [success,setSuccess]=useState<string|null>(null);
 const [needsReload,setNeedsReload]=useState(false);
 const row=rows.find(r=>r.store_id===storeId)??null;
 function applySelection(id:string,source:AdminFeaturedStore[]){
  const p=source.find(r=>r.store_id===id);
  const nextStart=p?datetimeLocal(p.starts_at):defaultStart();
  const nextEnd=p?.ends_at?datetimeLocal(p.ends_at):"";
  setStoreId(id);
  setPriority(String(p?.priority??10));setActive(p?.active??false);
  setStartsAt(nextStart);setEndsAt(nextEnd);
  setReason("");setError(null);setSuccess(null);
 }
 function select(id:string){if(!pending&&!needsReload)applySelection(id,rows);}
 async function reload(){
  const {data,error:e}=await createClient().rpc("admin_food_featured_stores")
   .abortSignal(AbortSignal.timeout(10_000));
  if(e)throw e;
  if(!Array.isArray(data))throw Error("Invalid response");
  const next=data as AdminFeaturedStore[];
  applySelection(storeId,next);setRows(next);setNeedsReload(false);router.refresh();
 }
 const startTime=Date.parse(startsAt),endTime=endsAt?Date.parse(endsAt):null,order=Number(priority);
 const valid=!!storeId && Number.isInteger(order)&&order>=1&&order<=100
  && Number.isFinite(startTime) && (endTime===null||(Number.isFinite(endTime)&&endTime>startTime))
  && reason.trim().length>=5 && reason.trim().length<=300;
 function save(){
  setError(null);setSuccess(null);
  if(!canEdit||!valid||pending||needsReload)return;
  if(!window.confirm(`ยืนยันตั้งค่าร้านแนะนำ? หากเปิดใช้งานและอยู่ในช่วงเวลาที่กำหนด ร้านอาจปรากฏบนหน้าแรก Food ทันที`))return;
  startTransition(async()=>{
   let saved=false;
   try{
    const {error:e}=await createClient().rpc("admin_save_food_featured_store",{
     p_store_id:storeId,p_expected_version:row?.version??null,p_priority:order,p_active:active,
     p_starts_at:new Date(startsAt).toISOString(),
     p_ends_at:endsAt?new Date(endsAt).toISOString():null,p_reason:reason.trim(),
    }).abortSignal(AbortSignal.timeout(20_000));
    if(e)throw e;
    saved=true;setNeedsReload(true);
    await reload();setSuccess("บันทึกค่าร้านแนะนำจริงและโหลดข้อมูลใหม่เรียบร้อย");
   }catch(e){
    const message=e&&typeof e==="object"&&"message" in e?String(e.message):String(e);
    const code=e&&typeof e==="object"&&"code" in e?String(e.code):"";
    const uncertain=!saved&&code!=="P0001"&&!/^22|^23|^42/.test(code);
    if(uncertain)setNeedsReload(true);
    setError(saved?"บันทึกสำเร็จ แต่โหลดข้อมูลล่าสุดไม่สำเร็จ กรุณาโหลดข้อมูลล่าสุดก่อนทำรายการต่อ":uncertain?
      "ยังยืนยันผลการบันทึกไม่ได้ กรุณาโหลดข้อมูลล่าสุดและตรวจรายการก่อนบันทึกอีกครั้ง":
      message.includes("placement changed")?"ข้อมูลถูกแก้จากที่แสดง กรุณาโหลดข้อมูลใหม่":message.includes("Not authorized")?
      "บัญชีนี้ไม่มีสิทธิ์ food:edit":"บันทึกไม่สำเร็จ: "+message);
   }
  });
 }
 return <section className="space-y-5 rounded-2xl border bg-background p-4 sm:p-6">
  <div className="grid gap-4 sm:grid-cols-2">
   <label className="block text-sm font-medium">
    เลือกร้าน
    <select value={storeId} disabled={pending||needsReload} onChange={e=>select(e.target.value)}
      className="mt-2 h-11 w-full rounded-lg border bg-background px-3 text-sm">
     {stores.length===0?<option value="">ไม่พบร้าน</option>:null}
     {stores.map(s=><option key={s.id} value={s.id}>{s.name}</option>)}
    </select>
   </label>
   <label className="block text-sm font-medium">
    ลำดับร้านแนะนำ (1 มาก่อน)
    <input type="number" min="1" max="100" step="1" disabled={!canEdit||pending}
      value={priority} onChange={e=>setPriority(e.target.value)}
      className="mt-2 h-11 w-full rounded-lg border bg-background px-3 text-sm tabular-nums"/>
   </label>
  </div>
  <p className="text-xs text-muted-foreground">
   {row?`มีการตั้งค่าร้านนี้แล้ว · เวอร์ชัน ${row.version}`:"ยังไม่ได้ตั้งค่าร้านนี้ · บันทึกเพื่อเพิ่มรายการใหม่"}
  </p>
  <div className="grid gap-4 sm:grid-cols-2">
   <label className="block text-sm font-medium">เริ่มแสดง (เวลาท้องถิ่น)
    <input type="datetime-local" value={startsAt} disabled={!canEdit||pending}
      onChange={e=>setStartsAt(e.target.value)}
      className="mt-2 h-11 w-full rounded-lg border bg-background px-3 text-sm"/>
   </label>
   <label className="block text-sm font-medium">หยุดแสดง (ไม่กำหนดได้)
    <input type="datetime-local" value={endsAt} disabled={!canEdit||pending}
      onChange={e=>setEndsAt(e.target.value)}
      className="mt-2 h-11 w-full rounded-lg border bg-background px-3 text-sm"/>
   </label>
  </div>
  <label className="flex items-center gap-3 text-sm font-medium">
   <input type="checkbox" checked={active} disabled={!canEdit||pending}
    onChange={e=>setActive(e.target.checked)} className="size-4"/>
   เปิดใช้งานร้านแนะนำ
  </label>
  {canEdit?<><label className="block text-sm font-medium">เหตุผลการเปลี่ยนแปลง
   <textarea rows={2} maxLength={300} value={reason} disabled={pending}
    onChange={e=>setReason(e.target.value)}
    className="mt-2 block w-full rounded-lg border bg-background p-3 text-sm"/>
  </label>
  <div className="flex flex-wrap gap-2">
   <button type="button" disabled={!valid||pending||needsReload} onClick={save}
    className="min-h-11 rounded-lg bg-foreground px-5 text-sm font-semibold text-background disabled:opacity-40">
    {pending?"กำลังบันทึก…":"ตรวจและยืนยันบันทึกจริง"}
   </button>
   <button type="button" disabled={pending} onClick={()=>startTransition(async()=>{
      try{setError(null);setSuccess(null);await reload();setSuccess("โหลดข้อมูลล่าสุดแล้ว");}catch(e){setError("โหลดข้อมูลไม่ได้ ข้อมูลที่แก้ไขยังอยู่: "+String(e));}
     })} className="min-h-11 rounded-lg border px-5 text-sm font-medium">
    โหลดข้อมูลล่าสุด
   </button>
  </div></>:<p className="text-sm text-muted-foreground">ดูข้อมูลได้เท่านั้น ต้องมี food:edit จึงเปลี่ยนได้</p>}
  {error?<p role="alert" className="text-sm text-red-600">{error}</p>:null}
  {success?<p role="status" className="text-sm">{success}</p>:null}
  <div className="space-y-2 border-t pt-5">
   <h2 className="text-sm font-semibold">รายการร้านที่ตั้งค่าแล้ว</h2>
   {rows.length===0?<p className="text-sm text-muted-foreground">ยังไม่มีร้านแนะนำ (ไม่เปลี่ยนลำดับหน้า Food ปัจจุบัน)</p>:
    <div className="space-y-2">{rows.map(r=><button type="button" key={r.store_id} disabled={pending||needsReload} onClick={()=>select(r.store_id)}
     className="flex w-full items-center justify-between rounded-lg border px-3 py-3 text-left text-sm hover:bg-accent">
     <span>{r.store_name}</span>
     <span className="text-xs text-muted-foreground">{r.active?"เปิด":"ปิด"} · อันดับ {r.priority}</span>
    </button>)}</div>}
  </div>
  <p className="text-xs leading-relaxed text-muted-foreground">ร้านแนะนำจะแสดงเฉพาะเมื่อร้านนั้นปรากฏในรายการร้านที่ผู้ใช้ดูได้อยู่แล้ว ไม่เปลี่ยนการค้นหา การกำหนดเขตจัดส่ง และไม่แก้คำสั่งซื้อเดิม</p>
 </section>;
}
