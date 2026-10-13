"use client";
import { useMemo,useState,useTransition } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import type { FoodReviewModerationRow } from "@/lib/admin-food-reviews";

export function FoodReviewModeration({initial,canEdit}:{
 initial:FoodReviewModerationRow[];canEdit:boolean;
}){
 const router=useRouter();
 const [items,setItems]=useState(initial);
 const [filter,setFilter]=useState<"all"|"visible"|"hidden">("all");
 const [selectedId,setSelectedId]=useState(initial[0]?.id??"");
 const [reason,setReason]=useState("");
 const [error,setError]=useState<string|null>(null);
 const [success,setSuccess]=useState<string|null>(null);
 const [saving,startTransition]=useTransition();
 const filtered=useMemo(()=>items.filter(item=>
   filter==="all" || (filter==="hidden"?item.is_hidden:!item.is_hidden)
 ),[items,filter]);
 const selected=items.find(item=>item.id===selectedId)??null;
 const selectedVisible=filtered.some(item=>item.id===selectedId);
 async function reload(){
   const {data,error:readError}=await createClient().rpc("admin_food_review_moderation_feed",{p_limit:200});
   if(readError)throw readError;
   if(!Array.isArray(data))throw Error("Unexpected review response");
   setItems(data as FoodReviewModerationRow[]);
   router.refresh();
 }
 function moderate(){
  setError(null);setSuccess(null);
  if(!canEdit||saving||!selected)return;
  if(reason.trim().length<5||reason.trim().length>300){
    setError("กรุณาระบุเหตุผล 5–300 ตัวอักษร");return;
  }
  const nextHidden=!selected.is_hidden;
  if(!window.confirm(nextHidden?
    `ยืนยันซ่อนรีวิวของร้าน “${selected.store_name}” จากหน้า Food?`:
    `ยืนยันคืนการแสดงผลรีวิวของร้าน “${selected.store_name}”?`))return;
  startTransition(async()=>{
   try{
     const {error:writeError}=await createClient().rpc("admin_set_food_review_hidden",{
       p_review_id:selected.id,p_expected_updated_at:selected.updated_at,
       p_hidden:nextHidden,p_reason:reason.trim(),
     });
     if(writeError)throw writeError;
     await reload();setReason("");
     setSuccess(nextHidden?"ซ่อนรีวิวสำเร็จ":"คืนการแสดงรีวิวสำเร็จ");
   }catch(e){
     const message=e instanceof Error?e.message:String(e);
     setError(message.includes("Review changed")?"ข้อมูลถูกแก้ไขจากที่แสดง กรุณาโหลดใหม่":
       message.includes("Not authorized")?"บัญชีไม่มีสิทธิ์ food:edit":"บันทึกไม่สำเร็จ: "+message);
   }
  });
 }
 return <div className="space-y-4 rounded-2xl border bg-background p-4 sm:p-6">
  <div className="flex flex-wrap gap-2">
   {(["all","visible","hidden"] as const).map(v=><button key={v} type="button"
     onClick={()=>{setFilter(v);setError(null);setSuccess(null);}}
     aria-pressed={filter===v}
     className={`rounded-lg border px-4 py-2 text-sm ${filter===v?"bg-foreground text-background":"hover:bg-accent"}`}>
      {v==="all"?"ทั้งหมด":v==="visible"?"แสดงอยู่":"ซ่อนอยู่"}
     </button>)}
  </div>
  <div className="grid gap-4 lg:grid-cols-[minmax(230px,1fr)_minmax(0,1.5fr)]">
   <div className="max-h-[540px] overflow-y-auto rounded-xl border">
    {filtered.length?filtered.map(item=><button key={item.id} type="button"
      onClick={()=>{setSelectedId(item.id);setReason("");setError(null);setSuccess(null);}}
      className={`block w-full border-b px-4 py-3 text-left text-sm last:border-b-0 hover:bg-accent ${selectedId===item.id?"bg-muted/60":""}`}>
      <span className="block font-medium">{item.store_name}</span>
      <span className="mt-1 block text-xs text-muted-foreground">
       {item.rating}/5 ★ · {item.is_hidden?"ซ่อนอยู่":"แสดงอยู่"} · {new Intl.DateTimeFormat("th-TH",{timeZone:"Asia/Bangkok",dateStyle:"medium"}).format(new Date(item.created_at))}
      </span>
      {item.review_text?<span className="mt-1 block text-xs text-muted-foreground line-clamp-2">{item.review_text}</span>:null}
    </button>):<p className="p-5 text-sm text-muted-foreground">ไม่มีรีวิวที่ตรงกับตัวกรองนี้</p>}
   </div>
   {selected&&selectedVisible?<div className="space-y-4 rounded-xl border p-4">
     <div className="space-y-1">
       <h2 className="text-base font-semibold">{selected.store_name}</h2>
       <p className="text-xs text-muted-foreground">
        {selected.rating}/5 ★ · {selected.reviewer_label} · {selected.is_hidden?"ซ่อน":"แสดง"}
       </p>
     </div>
     <p className="whitespace-pre-wrap text-sm">{selected.review_text||"รีวิวให้คะแนนโดยไม่มีข้อความ"}</p>
     {selected.tags.length?<p className="text-xs text-muted-foreground">{selected.tags.join(" · ")}</p>:null}
     {selected.merchant_reply?<div className="rounded-lg bg-muted p-3 text-sm">
       <strong>คำตอบร้าน</strong><p className="mt-2 whitespace-pre-wrap">{selected.merchant_reply}</p>
     </div>:null}
     {canEdit?<><label className="block text-sm font-medium">
       เหตุผลการซ่อนหรือคืนการแสดงผล (จำเป็น)
       <textarea value={reason} onChange={e=>setReason(e.target.value)} maxLength={300} rows={3}
         placeholder="เช่น ตรวจพบเนื้อหาละเมิดข้อกำหนดชุมชน"
         disabled={saving} className="mt-2 block w-full rounded-lg border bg-background p-3 text-sm"/>
     </label>
     <button type="button" onClick={moderate} disabled={saving||reason.trim().length<5}
       className="min-h-11 rounded-lg bg-foreground px-5 text-sm font-semibold text-background disabled:opacity-40">
       {saving?"กำลังบันทึก…":selected.is_hidden?"ยืนยันคืนการแสดงรีวิว":"ยืนยันซ่อนรีวิว"}
     </button></>:<p className="text-sm text-muted-foreground">ต้องมี food:edit เพื่อเปลี่ยนสถานะรีวิว</p>}
   </div>:<p className="text-sm text-muted-foreground">เลือกรีวิวจากรายการด้านซ้าย</p>}
  </div>
  <button type="button" disabled={saving} onClick={()=>startTransition(async()=>{
    try{setError(null);await reload();setSuccess("โหลดรีวิวล่าสุดแล้ว");}
    catch(e){setError("โหลดข้อมูลล่าสุดไม่สำเร็จ: "+String(e));}
  })} className="min-h-11 rounded-lg border px-5 text-sm font-medium">โหลดข้อมูลล่าสุด</button>
  {error?<p role="alert" className="text-sm text-red-600">{error}</p>:null}
  {success?<p role="status" className="text-sm">{success}</p>:null}
  <p className="text-xs text-muted-foreground">
   การซ่อนรีวิวจะทำให้ไม่ปรากฏในฟีดและการคำนวณคะแนนเฉลี่ยใหม่ตามกลไก Food เดิม
   ไม่ลบรีวิวหรือแก้ประวัติลูกค้า ระบบจำกัดสิทธิ์และตรวจการเปลี่ยนแปลงที่เกิดจากผู้อื่นก่อนบันทึก
  </p>
 </div>;
}
