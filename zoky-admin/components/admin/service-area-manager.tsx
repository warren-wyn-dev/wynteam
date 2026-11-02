"use client";

import { useMemo, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Globe2, MapPin, Search } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { serviceAreaError, type ServiceArea, type ServiceAreaData } from "@/lib/admin-service-area-types";
import { createClient } from "@/lib/supabase/client";

type Filter = "all" | "open" | "closed";

export function ServiceAreaManager({ initial }: { initial: ServiceAreaData }) {
  const router = useRouter();
  const [areas, setAreas] = useState<ServiceArea[]>(initial.areas);
  const [query, setQuery] = useState("");
  const [filter, setFilter] = useState<Filter>("all");
  const [busy, setBusy] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [, startTransition] = useTransition();
  const canEdit = initial.canEdit;

  const country = areas.find((area) => area.kind === "country") ?? null;
  const provinces = areas.filter((area) => area.kind !== "country");
  const openProvinces = provinces.filter((area) => area.active).length;
  const nationwide = country?.active === true;

  const visible = useMemo(() => {
    const term = query.trim().toLocaleLowerCase("th");
    return provinces.filter((area) => {
      if (filter === "open" && !area.active) return false;
      if (filter === "closed" && area.active) return false;
      if (!term) return true;
      return area.name.toLocaleLowerCase("th").includes(term) || (area.name_en ?? "").toLowerCase().includes(term);
    });
  }, [provinces, query, filter]);

  function toggle(area: ServiceArea) {
    if (!canEdit || busy) return;
    const next = !area.active;
    const message = area.kind === "country"
      ? next
        ? "เปิดให้บริการทั้งประเทศ? ลูกค้าและร้านทุกจังหวัดจะสั่งและเปิดขายได้ทันที"
        : `ปิดการเปิดทั้งประเทศ? จะเหลือเฉพาะจังหวัดที่เปิดไว้ (${openProvinces} จังหวัด) ลูกค้าและร้านนอกจังหวัดเหล่านี้จะสั่งและเปิดขายไม่ได้ทันที`
      : next
        ? `เปิดให้บริการที่${area.name}?`
        : `ปิดให้บริการที่${area.name}?${nationwide ? " (ตอนนี้เปิดทั้งประเทศอยู่ จึงยังสั่งได้จนกว่าจะปิดการเปิดทั้งประเทศ)" : " ลูกค้าและร้านในจังหวัดนี้จะสั่งและเปิดขายไม่ได้ทันที"}`;
    if (!window.confirm(message)) return;
    setError(null);
    setNotice(null);
    setBusy(area.group_code);
    startTransition(async () => {
      try {
        const supabase = createClient();
        const { error: setError_ } = await supabase.rpc("admin_zoky_set_service_area", {
          p_group_code: area.group_code,
          p_active: next,
        });
        if (setError_) throw setError_;
        const { data, error: reloadError } = await supabase.rpc("admin_zoky_service_areas");
        if (reloadError) throw reloadError;
        const value = (data ?? {}) as { areas?: unknown };
        if (Array.isArray(value.areas)) setAreas(value.areas as ServiceArea[]);
        setNotice(`${next ? "เปิด" : "ปิด"}ให้บริการ${area.kind === "country" ? "ทั้งประเทศ" : `ที่${area.name}`}แล้ว`);
        router.refresh();
      } catch (caught) {
        setError(serviceAreaError(caught));
      } finally {
        setBusy(null);
      }
    });
  }

  return (
    <section className="space-y-5">
      {!canEdit ? (
        <p className="rounded-xl border bg-muted/40 p-3 text-sm text-muted-foreground">ดูได้อย่างเดียว เฉพาะ Super admin เท่านั้นที่เปลี่ยนพื้นที่ให้บริการได้</p>
      ) : null}
      {error ? <p role="alert" className="rounded-xl border border-destructive/40 bg-destructive/10 p-3 text-sm text-destructive">{error}</p> : null}
      {notice ? <p role="status" className="rounded-xl border bg-primary/10 p-3 text-sm">{notice}</p> : null}

      {country ? (
        <div className={`flex flex-wrap items-center gap-4 rounded-2xl border p-4 sm:p-5 ${country.active ? "border-primary/40 bg-primary/5" : "bg-background"}`}>
          <span className="grid size-11 place-items-center rounded-full bg-primary/10 text-primary"><Globe2 className="size-5" aria-hidden="true" /></span>
          <div className="min-w-[12rem] flex-1">
            <div className="flex flex-wrap items-center gap-2">
              <h2 className="text-base font-semibold">ทั้งประเทศไทย</h2>
              <Badge variant={country.active ? "default" : "gray-tonal"}>{country.active ? "เปิดอยู่" : "ปิดอยู่"}</Badge>
            </div>
            <p className="text-sm text-muted-foreground">
              {country.active
                ? "ทุกจังหวัดสั่งและเปิดร้านได้ การปิดรายจังหวัดด้านล่างจะมีผลเมื่อปิดตัวเลือกนี้"
                : `เปิดเฉพาะจังหวัดที่เลือก (${openProvinces} จังหวัด)`}
            </p>
          </div>
          <Button
            type="button"
            className="w-full sm:w-auto"
            variant={country.active ? "outline" : "default"}
            disabled={!canEdit || busy !== null}
            aria-pressed={country.active}
            onClick={() => toggle(country)}
          >
            {busy === country.group_code ? "กำลังบันทึก…" : country.active ? "ปิดทั้งประเทศ" : "เปิดทั้งประเทศ"}
          </Button>
        </div>
      ) : null}

      <div className="space-y-3 rounded-2xl border bg-background p-4 sm:p-5">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <h2 className="text-base font-semibold">รายจังหวัด <span className="text-sm font-normal text-muted-foreground">เปิด {openProvinces} จาก {provinces.length}</span></h2>
          <div className="flex gap-1" role="group" aria-label="กรองจังหวัด">
            {(["all", "open", "closed"] as const).map((value) => (
              <Button key={value} type="button" size="sm" variant={filter === value ? "default" : "outline"} aria-pressed={filter === value} onClick={() => setFilter(value)}>
                {value === "all" ? "ทั้งหมด" : value === "open" ? "เปิด" : "ปิด"}
              </Button>
            ))}
          </div>
        </div>
        <label className="relative block">
          <Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" aria-hidden="true" />
          <Input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="ค้นหาจังหวัด" aria-label="ค้นหาจังหวัด" className="pl-9" />
        </label>
        {visible.length ? (
          <ul className="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
            {visible.map((area) => {
              const effective = area.active || nationwide;
              return (
                <li key={area.group_code} className={`flex items-center gap-3 rounded-xl border p-3 ${area.active ? "border-primary/40 bg-primary/5" : ""}`}>
                  <MapPin className={`size-4 shrink-0 ${effective ? "text-primary" : "text-muted-foreground"}`} aria-hidden="true" />
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-medium">{area.name}</p>
                    <p className={`truncate text-xs ${area.active ? "font-medium text-primary" : "text-muted-foreground"}`}>
                      {area.active ? "เปิดอยู่" : nationwide ? "ปิด · ยังสั่งได้เพราะเปิดทั้งประเทศ" : "ปิดอยู่"}
                    </p>
                  </div>
                  <Button
                    type="button"
                    size="sm"
                    variant="outline"
                    className="min-w-14"
                    disabled={!canEdit || busy !== null}
                    aria-pressed={area.active}
                    aria-label={`${area.active ? "ปิด" : "เปิด"}ให้บริการที่${area.name}`}
                    onClick={() => toggle(area)}
                  >
                    {busy === area.group_code ? "…" : area.active ? "ปิด" : "เปิด"}
                  </Button>
                </li>
              );
            })}
          </ul>
        ) : (
          <p className="rounded-xl border border-dashed p-6 text-center text-sm text-muted-foreground">ไม่พบจังหวัดที่ตรงกับการค้นหา</p>
        )}
      </div>
      <p className="text-xs text-muted-foreground">ทุกการเปลี่ยนแปลงถูกบันทึกใน Audit Log · ต้องเปิดไว้อย่างน้อย 1 พื้นที่ · ขอบเขตจังหวัด © OpenStreetMap contributors (ODbL)</p>
    </section>
  );
}
