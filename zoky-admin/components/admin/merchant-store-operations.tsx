"use client";

import { useState,useTransition } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import type { MerchantStoreOps } from "@/lib/admin-merchant-store-ops";

type Draft={
 open:boolean;until:string;tempReason:string;min:string;max:string;
};
function local(iso:string):string {
 const d=new Date(iso);
 return new Date(d.getTime()-d.getTimezoneOffset()*60000).toISOString().slice(0,16);
}
function fromRow(s:MerchantStoreOps):Draft{
 return {open:s.is_open,until:s.temporary_closed_until?local(s.temporary_closed_until):"",
  tempReason:s.temporary_closed_reason??"",min:String(s.prep_time_min_minutes),max:String(s.prep_time_max_minutes)};
}
function expected(s:MerchantStoreOps){
 return {is_open:s.is_open,temporary_closed_until:s.temporary_closed_until,
   temporary_closed_reason:s.temporary_closed_reason,prep_time_min_minutes:s.prep_time_min_minutes,
   prep_time_max_minutes:s.prep_time_max_minutes};
}
export function MerchantStoreOperations({initial,canEdit}:{
 initial:MerchantStoreOps[];canEdit:boolean;
}){
 const router=useRouter();
 const [items,setItems]=useState(initial);
 const [id,setId]=useState(initial[0]?.id??"");
 const selected=items.find(x=>x.id===id)??null;
 const [form,setForm]=useState<Draft>(selected?fromRow(selected):{open:false,until:"",tempReason:"",min:"15",max:"30"});
 const [reason,setReason]=useState("");
 const [error,setError]=useState<string|null>(null);
 const [success,setSuccess]=useState<string|null>(null);
 const [pending,startTransition]=useTransition();
 function select(storeId:string,all=items){
  setId(storeId);
  const s=all.find(x=>x.id===storeId);
  if(s)setForm(fromRow(s));
  setReason("");setError(null);setSuccess(null);
 }
 const min=Number(form.min),max=Number(form.max);
 const until=form.until?Date.parse(form.until):null;
 const validTime=Number.isInteger(min)&&min>=1&&min<=240&&Number.isInteger(max)&&max>=min&&max<=240;
 const validClose=until===null?!form.tempReason.trim():Number.isFinite(until)
   && form.tempReason.trim().length>=5&&form.tempReason.trim().length<=200;
 const changed=!!selected && (
  form.open!==selected.is_open||
  form.until!==(selected.temporary_closed_until?local(selected.temporary_closed_until):"")||
  form.tempReason!==(selected.temporary_closed_reason??"")||
  min!==selected.prep_time_min_minutes||max!==selected.prep_time_max_minutes
 );
 async function reload(){
  const {data,error:e}=await createClient().rpc("admin_merchant_store_operations");
  if(e)throw e;
  if(!Array.isArray(data))throw Error("Unexpected store data");
  const rows=data as MerchantStoreOps[];setItems(rows);select(id,rows);router.refresh();
 }
 function save(){
  setError(null);setSuccess(null);
  if(!canEdit||!selected||!validTime||!validClose||!changed||reason.trim().length<5||reason.trim().length>300) {
   setError("กรอกข้อมูลให้ถูกต้อง ต้องมีการเปลี่ยนแปลงและระบุเหตุผล 5–300 ตัวอักษร");
   return;
  }
  if(until!==null && (until<=Date.now() || until>Date.now()+30*24*60*60*1000)){
   setError("กำหนดเวลาปิดชั่วคราวต้องอยู่ในอนาคตไม่เกิน 30 วัน");return;
  }
  const message=form.open?"เปิดรับออเดอร์ใหม่เมื่ออยู่ในเวลาเปิดร้านและไม่มีเงื่อนไขปิดอื่น":"หยุดรับออเดอร์ใหม่";
  if(!window.confirm(`ยืนยันแก้สถานะร้าน "${selected.name}"? ระบบจะ${message}ทันทีหลังบันทึก`))return;
  startTransition(async()=>{
   try{
    const {error:e}=await createClient().rpc("admin_update_merchant_store_operations",{
      p_store_id:selected.id,p_expected:expected(selected),
      p_is_open:form.open,
      p_temporary_closed_until:form.until?new Date(form.until).toISOString():null,
      p_temporary_closed_reason:form.until?form.tempReason.trim():null,
      p_prep_time_min_minutes:min,p_prep_time_max_minutes:max,
      p_reason:reason.trim(),
    });
    if(e)throw e;
    await reload();setSuccess("บันทึกสถานะร้านและโหลดข้อมูลล่าสุดสำเร็จ");
   }catch(e){
    const msg=e instanceof Error?e.message:String(e);
    setError(msg.includes("Store availability changed")?"ร้านมีการแก้ข้อมูลระหว่างเปิดหน้า กรุณาโหลดใหม่ก่อนบันทึก":
     msg.includes("Not authorized")?"คุณไม่มีสิทธิ์ merchant:edit":"บันทึกไม่สำเร็จ: "+msg);
   }
  });
 }
 return <section className="space-y-5 rounded-2xl border bg-background p-4 sm:p-6">
  <label className="block text-sm font-medium">เลือกร้านอาหาร
   <select value={id} onChange={e=>select(e.target.value)}
    className="mt-2 h-11 w-full rounded-lg border bg-background px-3 text-sm">
    {items.length===0?<option value="">ไม่มีร้าน</option>:null}
    {items.map(x=><option key={x.id} value={x.id}>{x.name}</option>)}
   </select>
  </label>
  {selected?<>
   <div className="rounded-lg bg-muted/30 p-3 text-xs text-muted-foreground">
    {selected.published?"ร้านเผยแพร่แล้ว":"ร้านยังไม่เผยแพร่"} · {selected.admin_suspended?
     "ร้านถูกระงับโดยผู้ดูแล การเปิดรับงานไม่สามารถยกเลิกการระงับได้":"ร้านไม่ได้ถูกระงับ"}
   </div>
   <label className="flex items-center gap-3 text-sm font-medium">
    <input type="checkbox" disabled={!canEdit||pending} checked={form.open}
     onChange={e=>setForm(x=>({...x,open:e.target.checked}))} className="size-4"/>
    เปิดรับออเดอร์ใหม่ (ขึ้นกับเวลาเปิดร้านและเงื่อนไขอื่นด้วย)
   </label>
   <div className="grid gap-4 sm:grid-cols-2">
    <label className="block text-sm font-medium">เตรียมอาหารขั้นต่ำ (นาที)
     <input type="number" min="1" max="240" step="1" value={form.min} disabled={!canEdit||pending}
      onChange={e=>setForm(x=>({...x,min:e.target.value}))}
      className="mt-2 h-11 w-full rounded-lg border bg-background px-3 text-sm"/>
    </label>
    <label className="block text-sm font-medium">เตรียมอาหารสูงสุด (นาที)
     <input type="number" min="1" max="240" step="1" value={form.max} disabled={!canEdit||pending}
      onChange={e=>setForm(x=>({...x,max:e.target.value}))}
      className="mt-2 h-11 w-full rounded-lg border bg-background px-3 text-sm"/>
    </label>
   </div>
   <label className="block text-sm font-medium">ปิดชั่วคราวจนถึง (เว้นว่างหากไม่ปิดชั่วคราว)
    <input type="datetime-local" disabled={!canEdit||pending} value={form.until}
     onChange={e=>setForm(x=>({...x,until:e.target.value,tempReason:e.target.value?x.tempReason:""}))}
     className="mt-2 h-11 w-full rounded-lg border bg-background px-3 text-sm"/>
   </label>
   {form.until?<label className="block text-sm font-medium">เหตุผลที่ร้านปิดชั่วคราว (5–200 ตัวอักษร)
    <textarea rows={2} maxLength={200} disabled={!canEdit||pending} value={form.tempReason}
     onChange={e=>setForm(x=>({...x,tempReason:e.target.value}))}
     className="mt-2 block w-full rounded-lg border bg-background p-3 text-sm"/>
   </label>:null}
   {canEdit?<><label className="block text-sm font-medium">เหตุผลที่ Admin แก้ไข (บังคับ)
    <textarea rows={2} maxLength={300} disabled={pending} value={reason}
     onChange={e=>setReason(e.target.value)}
     placeholder="เช่น ร้านยืนยันหยุดรับงานเพื่อปรับปรุงครัว"
     className="mt-2 block w-full rounded-lg border bg-background p-3 text-sm"/>
   </label>
   <div className="flex flex-wrap gap-2">
    <button type="button" disabled={!validTime||!validClose||!changed||reason.trim().length<5||pending}
     onClick={save} className="min-h-11 rounded-lg bg-foreground px-5 text-sm font-semibold text-background disabled:opacity-40">
     {pending?"กำลังบันทึก…":"ยืนยันบันทึกสถานะร้านจริง"}
    </button>
    <button type="button" disabled={pending} onClick={()=>startTransition(async()=>{try{await reload();setSuccess("โหลดข้อมูลล่าสุดแล้ว");setError(null);}catch(e){setError("โหลดข้อมูลไม่ได้: "+String(e));}})}
     className="min-h-11 rounded-lg border px-5 text-sm font-medium">โหลดข้อมูลล่าสุด</button>
   </div></>:<p className="text-sm text-muted-foreground">ดูข้อมูลได้เท่านั้น ต้องมี merchant:edit เพื่อบันทึก</p>}
   {error?<p role="alert" className="text-sm text-red-600">{error}</p>:null}
   {success?<p role="status" className="text-sm">{success}</p>:null}
  </>:<p className="text-sm text-muted-foreground">ไม่มีร้านให้ตั้งค่า</p>}
  <p className="text-xs leading-relaxed text-muted-foreground">ระบบนี้แก้เฉพาะค่าสถานะร้านและการเตรียมอาหาร ไม่แก้ตารางเวลารายวัน ยกเลิกออเดอร์เดิม หรือยกเลิกการระงับร้าน ทุกการแก้ไขต้องยืนยันและบันทึก Audit Log</p>
 </section>;
}
