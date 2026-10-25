"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import type { AdminFoodBanner, BannerStore } from "@/lib/admin-food-banners";

type Draft = {
  id: string | null;
  version: number | null;
  title: string;
  subtitle: string;
  imagePath: string;
  destinationStoreId: string;
  sortOrder: string;
  startsAt: string;
  endsAt: string;
  isActive: boolean;
};
function asLocal(value: string): string {
  const d=new Date(value);
  const local=new Date(d.getTime()-d.getTimezoneOffset()*60000);
  return local.toISOString().slice(0,16);
}
function emptyDraft(): Draft {
  return {
    id:null,version:null,title:"",subtitle:"",imagePath:"",
    destinationStoreId:"",sortOrder:"100",startsAt:asLocal(new Date().toISOString()),endsAt:"",
    isActive:false,
  };
}
function fromRow(row: AdminFoodBanner): Draft {
  return {
    id:row.id,version:row.version,title:row.title,subtitle:row.subtitle??"",
    imagePath:row.image_path,destinationStoreId:row.destination_store_id??"",
    sortOrder:String(row.sort_order),startsAt:asLocal(row.starts_at),
    endsAt:row.ends_at?asLocal(row.ends_at):"",isActive:row.is_active,
  };
}
function bannerImage(path: string) {
  return createClient().storage.from("food-banners").getPublicUrl(path).data.publicUrl;
}
export function FoodBannerManager({
  initial,stores,canEdit,
}: {
  initial:AdminFoodBanner[];stores:BannerStore[];canEdit:boolean;
}){
  const router=useRouter();
  const [banners,setBanners]=useState(initial);
  const [draft,setDraft]=useState<Draft>(emptyDraft);
  const [reason,setReason]=useState("");
  const [error,setError]=useState<string|null>(null);
  const [success,setSuccess]=useState<string|null>(null);
  const [uploading,setUploading]=useState(false);
  const [pending,startTransition]=useTransition();
  const original=draft.id?banners.find(b=>b.id===draft.id):null;
  const validImage=/^banners\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(png|jpg|jpeg|webp)$/.test(draft.imagePath);
  const start=Date.parse(draft.startsAt);
  const end=draft.endsAt?Date.parse(draft.endsAt):null;
  const order=Number(draft.sortOrder);
  const valid=Boolean(
    draft.title.trim().length>=2 && draft.title.trim().length<=90 &&
    draft.subtitle.trim().length<=180 &&
    validImage && Number.isInteger(order) && order>=0 && order<=9999 &&
    Number.isFinite(start) && (end===null || (Number.isFinite(end)&&end>start)) &&
    reason.trim().length>=5 && reason.trim().length<=300
  );
  const [history,setHistory]=useState<Array<{reason:string;created_at:string;actor_id:string}>>([]);
  function choose(b:AdminFoodBanner|null){
    setDraft(b?fromRow(b):emptyDraft());setReason("");setError(null);setSuccess(null);setHistory([]);
  }
  async function upload(file:File|null) {
    if(!canEdit || !file) return;
    setError(null);setSuccess(null);
    if(!["image/png","image/jpeg","image/webp"].includes(file.type) || file.size>5*1024*1024 || file.size===0){
      setError("รองรับเฉพาะ PNG/JPEG/WebP ขนาดไม่เกิน 5 MB");return;
    }
    const ext=file.type==="image/png"?"png":file.type==="image/webp"?"webp":"jpg";
    const path=`banners/${crypto.randomUUID()}.${ext}`;
    setUploading(true);
    try {
      const {error}=await createClient().storage.from("food-banners").upload(path,file,{
        upsert:false,contentType:file.type,cacheControl:"3600",
      });
      if(error)throw error;
      setDraft(d=>({...d,imagePath:path}));
      setSuccess("อัปโหลดภาพสำเร็จ กรุณาบันทึกแบนเนอร์เพื่อใช้งานจริง");
    }catch(err){
      setError("อัปโหลดภาพไม่สำเร็จ: "+(err instanceof Error?err.message:String(err)));
    }finally{setUploading(false);}
  }
  async function loadLatest(nextId?:string|null){
    const {data,error}=await createClient().rpc("admin_food_home_banners");
    if(error)throw error;
    const rows=(Array.isArray(data)?data:[]) as AdminFoodBanner[];
    setBanners(rows);
    if(nextId){
      const found=rows.find(x=>x.id===nextId);
      if(found)setDraft(fromRow(found));
    }
    router.refresh();
  }
  function save(){
    setError(null);setSuccess(null);
    if(!canEdit||!valid||uploading||pending)return;
    if(!window.confirm(`ยืนยันบันทึกแบนเนอร์ "${draft.title}"? หากเปิดใช้งานและอยู่ในช่วงเวลา ภาพจะแสดงต่อผู้ใช้ Food ทันที`))return;
    startTransition(async()=>{
      try{
        const {data,error}=await createClient().rpc("admin_save_food_home_banner",{
          p_id:draft.id,
          p_expected_version:draft.version,
          p_title:draft.title.trim(),
          p_subtitle:draft.subtitle.trim()||null,
          p_image_path:draft.imagePath,
          p_destination_store_id:draft.destinationStoreId||null,
          p_sort_order:order,
          p_starts_at:new Date(draft.startsAt).toISOString(),
          p_ends_at:draft.endsAt?new Date(draft.endsAt).toISOString():null,
          p_is_active:draft.isActive,
          p_reason:reason.trim(),
        });
        if(error)throw error;
        setReason("");
        await loadLatest((data as AdminFoodBanner)?.id);
        setSuccess("บันทึกแบนเนอร์และโหลดข้อมูลล่าสุดเรียบร้อย");
      }catch(err){
        const message=err instanceof Error?err.message:String(err);
        setError(message.includes("Banner changed")?"ข้อมูลถูกแก้ไขจากที่แสดง กรุณาโหลดข้อมูลล่าสุด":message.includes("Not authorized")?
          "บัญชีนี้ไม่มีสิทธิ์ food:edit":"บันทึกไม่สำเร็จ: "+message);
      }
    });
  }
  function readHistory(){
    if(!draft.id)return;
    startTransition(async()=>{
      setError(null);
      const {data,error}=await createClient().rpc("admin_food_banner_history",{p_banner_id:draft.id});
      if(error){setError("ดึงประวัติไม่สำเร็จ: "+error.message);return;}
      setHistory(Array.isArray(data)?data:[]);
    });
  }
  return <section className="space-y-5">
    <div className="rounded-xl border bg-background p-4 space-y-3">
      <label className="block text-sm font-medium">
        เลือกแบนเนอร์
        <select value={draft.id??"new"} onChange={e=>choose(banners.find(b=>b.id===e.target.value)??null)}
          className="mt-2 h-11 w-full rounded-lg border bg-background px-3 text-sm">
          <option value="new">+ สร้างแบนเนอร์ใหม่</option>
          {banners.map(b=><option value={b.id} key={b.id}>
            {b.is_active?"● ":"○ "}{b.title} — ลำดับ {b.sort_order}
          </option>)}
        </select>
      </label>
      <div className="grid gap-4 sm:grid-cols-2">
        <label className="block text-sm font-medium">
          หัวข้อแบนเนอร์
          <input type="text" maxLength={90} disabled={!canEdit||pending} value={draft.title}
            onChange={e=>setDraft(d=>({...d,title:e.target.value}))}
            className="mt-2 h-11 w-full rounded-lg border bg-background px-3 text-sm"/>
        </label>
        <label className="block text-sm font-medium">
          ลำดับแสดง (เลขน้อยขึ้นก่อน)
          <input type="number" min="0" max="9999" step="1" disabled={!canEdit||pending} value={draft.sortOrder}
            onChange={e=>setDraft(d=>({...d,sortOrder:e.target.value}))}
            className="mt-2 h-11 w-full rounded-lg border bg-background px-3 text-sm"/>
        </label>
      </div>
      <label className="block text-sm font-medium">
        ข้อความอธิบาย
        <input type="text" maxLength={180} disabled={!canEdit||pending} value={draft.subtitle}
          onChange={e=>setDraft(d=>({...d,subtitle:e.target.value}))}
          className="mt-2 h-11 w-full rounded-lg border bg-background px-3 text-sm"/>
      </label>
      <label className="block text-sm font-medium">
        อัปโหลดภาพแบนเนอร์ (ไม่เกิน 5 MB)
        <input type="file" accept="image/png,image/jpeg,image/webp" disabled={!canEdit||uploading||pending}
          onChange={e=>{void upload(e.target.files?.[0]??null);e.target.value="";}}
          className="mt-2 block w-full rounded-lg border p-3 text-sm"/>
      </label>
      {draft.imagePath?<div className="overflow-hidden rounded-xl border">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src={bannerImage(draft.imagePath)} alt="ตัวอย่างแบนเนอร์" className="aspect-[2.4/1] w-full object-cover"/>
      </div>:null}
      {uploading?<p role="status" className="text-sm">กำลังอัปโหลดภาพ…</p>:null}
      <label className="block text-sm font-medium">
        ปลายทางเมื่อแตะแบนเนอร์
        <select value={draft.destinationStoreId} disabled={!canEdit||pending}
          onChange={e=>setDraft(d=>({...d,destinationStoreId:e.target.value}))}
          className="mt-2 h-11 w-full rounded-lg border bg-background px-3 text-sm">
          <option value="">ไม่มีลิงก์ — แบนเนอร์เพื่อประชาสัมพันธ์</option>
          {stores.map(s=><option value={s.id} key={s.id}>{s.name}</option>)}
        </select>
      </label>
      <div className="grid gap-4 sm:grid-cols-2">
        <label className="block text-sm font-medium">
          เริ่มแสดง (เวลาท้องถิ่น)
          <input type="datetime-local" disabled={!canEdit||pending} value={draft.startsAt}
            onChange={e=>setDraft(d=>({...d,startsAt:e.target.value}))}
            className="mt-2 h-11 w-full rounded-lg border bg-background px-3 text-sm"/>
        </label>
        <label className="block text-sm font-medium">
          หยุดแสดง (เว้นว่าง = ไม่มีกำหนด)
          <input type="datetime-local" disabled={!canEdit||pending} value={draft.endsAt}
            onChange={e=>setDraft(d=>({...d,endsAt:e.target.value}))}
            className="mt-2 h-11 w-full rounded-lg border bg-background px-3 text-sm"/>
        </label>
      </div>
      <label className="flex items-center gap-3 text-sm font-medium">
        <input type="checkbox" className="size-4 rounded border" disabled={!canEdit||pending} checked={draft.isActive}
          onChange={e=>setDraft(d=>({...d,isActive:e.target.checked}))}/>
        เปิดใช้งานแบนเนอร์ (ต้องตรงช่วงเวลาจึงจะแสดงจริง)
      </label>
      {canEdit?<><label className="block text-sm font-medium">
        เหตุผลการเปลี่ยนแปลง (จำเป็น)
        <textarea rows={2} maxLength={300} disabled={pending} value={reason}
          onChange={e=>setReason(e.target.value)}
          className="mt-2 w-full rounded-lg border bg-background p-3 text-sm"
          placeholder="เช่น เพิ่มแบนเนอร์โปรโมชันประจำเดือน"/>
      </label>
      <div className="flex flex-wrap gap-2">
        <button type="button" onClick={save} disabled={!valid||pending||uploading}
          className="min-h-11 rounded-lg bg-foreground px-5 text-sm font-semibold text-background disabled:opacity-40">
          {pending?"กำลังบันทึก…":"ตรวจและยืนยันบันทึกจริง"}
        </button>
        <button type="button" disabled={pending||uploading} onClick={()=>startTransition(async()=>{
          try{setError(null);await loadLatest(draft.id);setSuccess("โหลดข้อมูลล่าสุดแล้ว");}catch(err){setError(String(err));}
        })} className="min-h-11 rounded-lg border px-5 text-sm font-medium">
          โหลดข้อมูลล่าสุด
        </button>
        {draft.id?<button type="button" disabled={pending} onClick={readHistory} className="min-h-11 rounded-lg border px-5 text-sm font-medium">
          ประวัติการแก้ไข
        </button>:null}
      </div></>:<p className="text-sm text-muted-foreground">คุณมีสิทธิ์ดูเท่านั้น การแก้ไขต้องใช้ food:edit</p>}
      {error?<p role="alert" className="text-sm text-red-600">{error}</p>:null}
      {success?<p role="status" className="text-sm font-medium">{success}</p>:null}
      {history.length?<div className="rounded-lg border p-3 text-xs">
        <strong>ประวัติล่าสุด</strong>
        <ul className="mt-2 space-y-2">
          {history.map((h,i)=><li key={i}>{new Intl.DateTimeFormat("th-TH",{timeZone:"Asia/Bangkok",dateStyle:"medium",timeStyle:"short"}).format(new Date(h.created_at))} — {h.reason}</li>)}
        </ul>
      </div>:null}
    </div>
    <p className="text-xs leading-relaxed text-muted-foreground">
      การหยุดแบนเนอร์ให้เลือกแบนเนอร์แล้วปิดสวิตช์เปิดใช้งาน ไม่ลบประวัติ
      ผู้ดูแลต้องมีสิทธิ์ food:edit และทุกการบันทึกผ่านตรวจสิทธิ์ในฐานข้อมูล
      เก็บประวัติการเปลี่ยนแปลงและตรวจ version เพื่อป้องกันการบันทึกทับ
      การอัปโหลดไม่ได้ทำให้ภาพเผยแพร่โดยอัตโนมัติ ต้องกดบันทึกและเปิดใช้งาน
    </p>
  </section>;
}
