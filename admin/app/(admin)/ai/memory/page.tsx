import { Trash2 } from "lucide-react";

import { addMemoryAction, deleteMemoryAction } from "../actions";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { listMemoryItems } from "@/lib/ai/store";

const KIND_LABEL = { note: "โน้ต", decision: "การตัดสินใจ", context: "บริบท" } as const;

const fieldClass = "h-11 rounded-md border border-input bg-background px-3 text-sm";

export default async function AiMemoryPage({ searchParams }: { searchParams: Promise<{ status?: string }> }) {
  const [items, query] = await Promise.all([listMemoryItems(), searchParams]);

  return (
    <div className="flex flex-col gap-6">
      <p className="text-sm text-muted-foreground">
        สิ่งที่ AI ควรจำ เช่น การตัดสินใจที่อนุมัติแล้วหรือบริบทของงาน AI จะค้นจากที่นี่เมื่อเกี่ยวข้อง เห็นเฉพาะบัญชีคุณ มีวันหมดอายุ
        และลบได้ทุกเมื่อ ห้ามใส่รหัสผ่านหรือข้อมูลส่วนตัวของผู้ใช้
      </p>
      {query.status === "error" ? <p role="alert" className="rounded-lg bg-destructive/10 px-3 py-2 text-sm text-destructive">บันทึกไม่สำเร็จ</p> : null}

      <form action={addMemoryAction} className="flex flex-col gap-3 rounded-xl border bg-background p-4">
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="memory-content">เนื้อหา</Label>
          <Textarea id="memory-content" name="content" maxLength={2000} required rows={3} />
        </div>
        <div className="flex flex-wrap items-end gap-3">
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="memory-kind">ประเภท</Label>
            <select id="memory-kind" name="kind" defaultValue="note" className={fieldClass}>
              <option value="note">โน้ต</option>
              <option value="decision">การตัดสินใจ</option>
              <option value="context">บริบท</option>
            </select>
          </div>
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="memory-days">เก็บไว้</Label>
            <select id="memory-days" name="days" defaultValue="180" className={fieldClass}>
              <option value="30">30 วัน</option>
              <option value="90">90 วัน</option>
              <option value="180">180 วัน</option>
              <option value="365">1 ปี</option>
            </select>
          </div>
          <Button type="submit">บันทึกความจำ</Button>
        </div>
      </form>

      {items.length === 0 ? (
        <p className="rounded-xl border border-dashed p-8 text-center text-sm text-muted-foreground">ยังไม่มีความจำที่บันทึกไว้</p>
      ) : (
        <ul className="flex flex-col gap-2">
          {items.map((item) => (
            <li key={item.id} className="flex items-start justify-between gap-3 rounded-xl border bg-background p-3">
              <div className="flex min-w-0 flex-col gap-1">
                <span className="text-xs font-medium text-muted-foreground">
                  {KIND_LABEL[item.kind]} · หมดอายุ {new Date(item.expires_at).toLocaleDateString("th-TH", { timeZone: "Asia/Bangkok" })}
                </span>
                <p className="whitespace-pre-wrap break-words text-sm">{item.content}</p>
              </div>
              <form action={deleteMemoryAction}>
                <input type="hidden" name="id" value={item.id} />
                <Button type="submit" variant="ghost" aria-label="ลบความจำนี้">
                  <Trash2 className="size-4" aria-hidden />
                </Button>
              </form>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
