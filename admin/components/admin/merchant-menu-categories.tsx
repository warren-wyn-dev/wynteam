"use client";

import { useState } from "react";
import type { AdminMerchantMenuItem, AdminMerchantMenuStore } from "@/lib/admin-merchant-menu";

export type MenuCategoryChange = { order: string[]; renames: Record<string, string>; reason: string };

export function MerchantMenuCategories({ store, items, canEdit, pending, onSave }: {
  store: AdminMerchantMenuStore; items: AdminMerchantMenuItem[]; canEdit: boolean; pending: boolean;
  onSave: (change: MenuCategoryChange) => void;
}) {
  const original = [...new Set([...store.menu_category_order, ...items.map(item => item.category)])];
  const [rows, setRows] = useState(original.map(name => ({ original: name, name })));
  const [newName, setNewName] = useState("");
  const [reason, setReason] = useState("");
  const names = rows.map(row => row.name.trim());
  const invalid = names.some(name => !name || name.length > 60) || new Set(names).size !== names.length || names.length > 100;
  const changed = JSON.stringify(names) !== JSON.stringify(original);
  function move(index: number, direction: number) {
    const next = [...rows];
    [next[index], next[index + direction]] = [next[index + direction], next[index]];
    setRows(next);
  }
  return <details className="rounded-xl border p-4">
    <summary className="min-h-8 cursor-pointer text-sm font-semibold">หมวดหมู่ของร้าน {store.name}</summary>
    <fieldset disabled={!canEdit || pending} className="mt-4 space-y-3">
      <p className="text-xs text-muted-foreground">จัดลำดับ เพิ่มหมวดหมู่ หรือเปลี่ยนชื่อพร้อมย้ายเมนูในหมวดนั้น หมวดหมู่ที่มีเมนูอยู่ต้องย้ายเมนูก่อนลบ</p>
      {rows.map((row, index) => <div className="flex flex-wrap items-center gap-2" key={row.original || `new-${index}`}>
        <label className="min-w-40 flex-1 text-sm">
          <span className="sr-only">ชื่อหมวดหมู่ {index + 1}</span>
          <input className="min-h-11 w-full rounded-lg border bg-background px-3" value={row.name} maxLength={60}
            onChange={event => setRows(rows.map((item, target) => target === index ? { ...item, name: event.target.value } : item))} />
        </label>
        <button type="button" className="min-h-11 rounded-lg border px-3 text-sm disabled:opacity-40" disabled={pending || !canEdit || index === 0}
          onClick={() => move(index, -1)} aria-label={`เลื่อนหมวดหมู่ ${index + 1} ขึ้น`}>ขึ้น</button>
        <button type="button" className="min-h-11 rounded-lg border px-3 text-sm disabled:opacity-40" disabled={pending || !canEdit || index === rows.length - 1}
          onClick={() => move(index, 1)} aria-label={`เลื่อนหมวดหมู่ ${index + 1} ลง`}>ลง</button>
        <button type="button" className="min-h-11 rounded-lg border px-3 text-sm disabled:opacity-40"
          disabled={pending || !canEdit || items.some(item => item.category === row.original)}
          onClick={() => setRows(rows.filter((_, target) => target !== index))} aria-label={`ลบหมวดหมู่ ${index + 1}`}>ลบ</button>
      </div>)}
      <div className="flex flex-wrap gap-2">
        <label className="min-w-40 flex-1 text-sm"><span className="sr-only">ชื่อหมวดหมู่ใหม่</span>
          <input className="min-h-11 w-full rounded-lg border bg-background px-3" value={newName} maxLength={60} placeholder="ชื่อหมวดหมู่ใหม่"
            onChange={event => setNewName(event.target.value)} />
        </label>
        <button type="button" className="min-h-11 rounded-lg border px-3 text-sm disabled:opacity-40"
          disabled={!canEdit || pending || !newName.trim() || names.includes(newName.trim()) || rows.length >= 100}
          onClick={() => { setRows([...rows, { original: "", name: newName.trim() }]); setNewName(""); }}>เพิ่มหมวดหมู่</button>
      </div>
      <label className="block space-y-1 text-sm">เหตุผลการแก้หมวดหมู่
        <textarea rows={2} maxLength={300} value={reason} onChange={event => setReason(event.target.value)} className="w-full rounded-lg border bg-background p-3" />
      </label>
      {invalid ? <p className="text-sm text-red-600">ชื่อหมวดหมู่ต้องไม่ว่าง ไม่ซ้ำ และไม่เกิน 60 ตัวอักษร</p> : null}
      <button type="button" className="min-h-11 rounded-lg border px-4 text-sm font-medium disabled:opacity-40"
        disabled={!canEdit || pending || !changed || invalid || reason.trim().length < 5 || reason.trim().length > 300}
        onClick={() => onSave({ order: names, renames: Object.fromEntries(rows.filter(row => row.original && row.original !== row.name.trim()).map(row => [row.original, row.name.trim()])), reason: reason.trim() })}>บันทึกหมวดหมู่</button>
    </fieldset>
  </details>;
}
