import { Power, ShieldCheck } from "lucide-react";

import { setSecretaryEnabledAction, setSecretaryLimitsAction } from "../actions";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { MODEL_TIER_LABEL, MODEL_TIERS, resolveTier } from "@/lib/ai/models";
import { fetchSecretaryStatus, secretaryEnvironment } from "@/lib/ai/store";
import { SECRETARY_TOOLS } from "@/lib/ai/tools";
import { ADMIN_SYSTEM_LABEL } from "@/lib/admin-systems";

export default async function AiSettingsPage({ searchParams }: { searchParams: Promise<{ status?: string }> }) {
  const [status, query] = await Promise.all([fetchSecretaryStatus(), searchParams]);
  const env = secretaryEnvironment();

  return (
    <div className="flex flex-col gap-6">
      {query.status === "saved" ? <p role="status" className="rounded-lg bg-emerald-50 px-3 py-2 text-sm text-emerald-900 dark:bg-emerald-950 dark:text-emerald-100">บันทึกแล้ว</p> : null}
      {query.status === "error" ? <p role="alert" className="rounded-lg bg-destructive/10 px-3 py-2 text-sm text-destructive">บันทึกไม่สำเร็จ ตรวจค่าที่กรอกแล้วลองใหม่</p> : null}

      <section className="flex flex-col gap-3 rounded-xl border bg-background p-4">
        <div className="flex items-center gap-2">
          <Power className="size-4" aria-hidden />
          <h3 className="font-semibold">Kill switch</h3>
        </div>
        <p className="text-sm text-muted-foreground">
          ปิดแล้วจะหยุดรับคำถามใหม่ทันที (คำขอที่กำลังทำงานจะจบเอง) ทุกการเปลี่ยนแปลงถูกบันทึกใน Audit Log
        </p>
        <div className="flex flex-wrap items-center gap-3">
          <span className={status.enabled ? "font-medium text-emerald-700 dark:text-emerald-300" : "font-medium text-destructive"}>
            สถานะ: {status.enabled ? "เปิดใช้งาน" : "ปิดอยู่"}
          </span>
          <form action={setSecretaryEnabledAction}>
            <input type="hidden" name="enabled" value={status.enabled ? "false" : "true"} />
            <Button type="submit" variant={status.enabled ? "destructive" : "default"}>
              {status.enabled ? "ปิด AI Secretary" : "เปิด AI Secretary"}
            </Button>
          </form>
        </div>
        <p className="text-xs text-muted-foreground">
          สวิตช์ระดับ deploy: AI_SECRETARY_ENABLED = {env.enabledByEnv ? "true" : "ไม่ได้ตั้ง (ปิด)"} · provider key:{" "}
          {env.hasProviderKey ? "ตั้งค่าแล้ว" : "ยังไม่ได้ตั้ง"}
        </p>
      </section>

      <section className="flex flex-col gap-3 rounded-xl border bg-background p-4">
        <h3 className="font-semibold">ขีดจำกัดการใช้งาน</h3>
        <form action={setSecretaryLimitsAction} className="grid gap-3 sm:grid-cols-[1fr_1fr_auto] sm:items-end">
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="daily_token_limit">Token ต่อวัน (ต่อคน)</Label>
            <Input id="daily_token_limit" name="daily_token_limit" type="number" min={0} max={10000000} step={1000} defaultValue={status.dailyTokenLimit} required />
          </div>
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="requests_per_minute">คำถามต่อนาที</Label>
            <Input id="requests_per_minute" name="requests_per_minute" type="number" min={0} max={60} defaultValue={status.requestsPerMinute} required />
          </div>
          <Button type="submit" variant="outline">
            บันทึก
          </Button>
        </form>
        <p className="text-xs text-muted-foreground">ใช้ไปวันนี้ {status.tokensUsedToday.toLocaleString()} tokens (นับตามวันเวลาไทย)</p>
      </section>

      <section className="flex flex-col gap-3 rounded-xl border bg-background p-4">
        <h3 className="font-semibold">โมเดล</h3>
        <ul className="grid gap-2 sm:grid-cols-3">
          {MODEL_TIERS.map((tier) => {
            const config = resolveTier(tier);
            return (
              <li key={tier} className="rounded-lg bg-muted/50 p-3 text-sm">
                <p className="font-medium">{MODEL_TIER_LABEL[tier]}</p>
                <p className="text-xs text-muted-foreground">
                  {config.model} · effort {config.effort}
                </p>
              </li>
            );
          })}
        </ul>
      </section>

      <section className="flex flex-col gap-3 rounded-xl border bg-background p-4">
        <div className="flex items-center gap-2">
          <ShieldCheck className="size-4" aria-hidden />
          <h3 className="font-semibold">เครื่องมือที่ AI ใช้ได้</h3>
        </div>
        <p className="text-sm text-muted-foreground">
          Phase 1 มีเฉพาะระดับ 1 (อ่านและวิเคราะห์) ระดับ 2 (ดำเนินการที่ควบคุม) และระดับ 3 (การกระทำที่จำกัด) จะถูกปฏิเสธจนกว่าจะมีระบบอนุมัติ
        </p>
        <div className="overflow-x-auto rounded-lg border">
          <table className="w-full text-left text-sm">
            <thead className="bg-muted/60 text-xs">
              <tr>
                <th scope="col" className="px-3 py-2">เครื่องมือ</th>
                <th scope="col" className="px-3 py-2">ระบบ</th>
                <th scope="col" className="px-3 py-2">ระดับ</th>
              </tr>
            </thead>
            <tbody>
              {SECRETARY_TOOLS.map((tool) => (
                <tr key={tool.name} className="border-t">
                  <td className="px-3 py-2">
                    {tool.label}
                    <span className="block text-xs text-muted-foreground">{tool.name}</span>
                  </td>
                  <td className="px-3 py-2">{tool.system ? ADMIN_SYSTEM_LABEL[tool.system] : "—"}</td>
                  <td className="px-3 py-2">{tool.level} · อ่านอย่างเดียว</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}
