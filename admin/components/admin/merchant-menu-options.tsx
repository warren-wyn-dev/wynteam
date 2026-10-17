"use client";

import type { MenuOptionDraft } from "@/lib/admin-merchant-menu-form";

const inputClass = "min-h-11 w-full rounded-lg border bg-background px-3 text-sm disabled:opacity-60";
const buttonClass = "min-h-11 rounded-lg border px-3 text-sm disabled:opacity-40";

export function MerchantMenuOptions({ value, onChange, disabled }: {
  value: MenuOptionDraft[]; onChange: (value: MenuOptionDraft[]) => void; disabled: boolean;
}) {
  function update(index: number, update: Partial<MenuOptionDraft>) {
    onChange(value.map((group, position) => position === index ? { ...group, ...update } : group));
  }
  return <fieldset disabled={disabled} className="space-y-4 rounded-xl border p-4">
    <legend className="px-1 text-sm font-semibold">กลุ่มตัวเลือกและรายการเพิ่ม</legend>
    <p className="text-xs text-muted-foreground">ราคาเพิ่มจะรวมกับราคาอาหารสำหรับออเดอร์ใหม่ ตัวเลือกในออเดอร์เดิมเก็บตามข้อมูลขณะสั่งซื้อ</p>
    {value.length === 0 ? <p className="text-sm text-muted-foreground">ยังไม่มีกลุ่มตัวเลือก</p> : null}
    {value.map((group, index) => <div key={group.id} className="space-y-3 rounded-xl border p-3">
      <div className="grid items-end gap-3 sm:grid-cols-[1fr_auto]">
        <label className="space-y-1 text-sm">ชื่อกลุ่ม {index + 1}
          <input className={inputClass} value={group.name} maxLength={160}
            onChange={event => update(index, { name: event.target.value })} />
        </label>
        <button type="button" className={buttonClass} onClick={() => onChange(value.filter((_, position) => position !== index))}>
          ลบกลุ่ม {index + 1}
        </button>
      </div>
      <div className="flex flex-wrap items-center gap-4">
        <label className="flex min-h-11 items-center gap-2 text-sm">
          <input type="checkbox" checked={group.required} onChange={event => update(index, { required: event.target.checked })} />
          บังคับเลือก
        </label>
        <label className="flex items-center gap-2 text-sm">เลือกได้สูงสุด
          <input aria-label={`จำนวนที่เลือกได้จากกลุ่ม ${index + 1}`} type="number" min={1} max={Math.min(20, group.choices.length)} step={1}
            className="min-h-11 w-20 rounded-lg border bg-background px-3" value={group.max_select}
            onChange={event => update(index, { max_select: Number(event.target.value) })} />
        </label>
      </div>
      {group.choices.map((choice, position) => <div key={choice.id} className="grid items-end gap-2 sm:grid-cols-[1fr_8rem_auto]">
        <label className="space-y-1 text-sm">ตัวเลือก {position + 1}
          <input className={inputClass} maxLength={160} value={choice.name}
            onChange={event => update(index, { choices: group.choices.map((item, target) => target === position ? { ...item, name: event.target.value } : item) })} />
        </label>
        <label className="space-y-1 text-sm">ราคาเพิ่ม (บาท)
          <input className={inputClass} type="number" min={0} max={100000} step="0.01" value={choice.price}
            onChange={event => update(index, { choices: group.choices.map((item, target) => target === position ? { ...item, price: event.target.value } : item) })} />
        </label>
        <button type="button" className={buttonClass} aria-label={`ลบตัวเลือก ${position + 1} ในกลุ่ม ${index + 1}`}
          onClick={() => update(index, { choices: group.choices.filter((_, target) => target !== position),
            max_select: Math.min(group.max_select, Math.max(1, group.choices.length - 1)) })}>ลบ</button>
      </div>)}
      <button type="button" disabled={disabled || group.choices.length >= 50} className={buttonClass}
        onClick={() => update(index, { choices: [...group.choices, { id: crypto.randomUUID(), name: "", price: "0" }] })}>เพิ่มตัวเลือกในกลุ่ม {index + 1}</button>
    </div>)}
    <button type="button" disabled={disabled || value.length >= 20} className={buttonClass}
      onClick={() => onChange([...value, { id: crypto.randomUUID(), name: "", required: false, max_select: 1,
        choices: [{ id: crypto.randomUUID(), name: "", price: "0" }] }])}>เพิ่มกลุ่มตัวเลือก</button>
  </fieldset>;
}
