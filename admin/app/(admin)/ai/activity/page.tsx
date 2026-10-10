import { estimateCostUsd } from "@/lib/ai/models";
import { listToolRuns, listUsage } from "@/lib/ai/store";
import { cn } from "@/lib/utils";

const STATUS_LABEL: Record<string, string> = {
  succeeded: "สำเร็จ",
  failed: "ล้มเหลว",
  denied: "ถูกปฏิเสธ",
  timed_out: "หมดเวลา",
};

function bangkokDay(iso: string) {
  return new Date(iso).toLocaleDateString("en-CA", { timeZone: "Asia/Bangkok" });
}

export default async function AiActivityPage() {
  const [runs, usage] = await Promise.all([listToolRuns(100), listUsage(30)]);

  const byDay = new Map<string, { requests: number; tokens: number; cost: number; unpriced: boolean }>();
  for (const row of usage) {
    const day = bangkokDay(row.created_at);
    const entry = byDay.get(day) ?? { requests: 0, tokens: 0, cost: 0, unpriced: false };
    entry.requests += 1;
    entry.tokens += row.input_tokens + row.output_tokens;
    const cost = estimateCostUsd(row.model, row.input_tokens, row.output_tokens);
    if (cost === null) entry.unpriced = true;
    else entry.cost += cost;
    byDay.set(day, entry);
  }
  const days = [...byDay.entries()].sort(([a], [b]) => b.localeCompare(a));
  const total = days.reduce((sum, [, d]) => ({ tokens: sum.tokens + d.tokens, cost: sum.cost + d.cost }), { tokens: 0, cost: 0 });

  return (
    <div className="flex flex-col gap-6">
      <section className="grid gap-3 sm:grid-cols-3">
        <Stat label="คำขอ 30 วัน" value={usage.length.toLocaleString()} />
        <Stat label="Tokens 30 วัน" value={total.tokens.toLocaleString()} />
        <Stat label="ค่าใช้จ่ายโดยประมาณ" value={`$${total.cost.toFixed(2)}`} hint="ประมาณจากราคาต่อ token ไม่ใช่ใบแจ้งหนี้" />
      </section>

      <section className="flex flex-col gap-2">
        <h3 className="font-semibold">การใช้งานรายวัน (เวลาไทย)</h3>
        {days.length === 0 ? (
          <p className="rounded-xl border border-dashed p-6 text-center text-sm text-muted-foreground">ยังไม่มีการใช้งาน</p>
        ) : (
          <div className="overflow-x-auto rounded-lg border bg-background">
            <table className="w-full text-left text-sm">
              <thead className="bg-muted/60 text-xs">
                <tr>
                  <th scope="col" className="px-3 py-2">วันที่</th>
                  <th scope="col" className="px-3 py-2 text-right">คำขอ</th>
                  <th scope="col" className="px-3 py-2 text-right">Tokens</th>
                  <th scope="col" className="px-3 py-2 text-right">ค่าใช้จ่ายโดยประมาณ</th>
                </tr>
              </thead>
              <tbody>
                {days.map(([day, d]) => (
                  <tr key={day} className="border-t tabular-nums">
                    <td className="px-3 py-2">{day}</td>
                    <td className="px-3 py-2 text-right">{d.requests}</td>
                    <td className="px-3 py-2 text-right">{d.tokens.toLocaleString()}</td>
                    <td className="px-3 py-2 text-right">
                      ${d.cost.toFixed(3)}
                      {d.unpriced ? " +" : ""}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <section className="flex flex-col gap-2">
        <h3 className="font-semibold">ประวัติการเรียกเครื่องมือ (Audit)</h3>
        <p className="text-xs text-muted-foreground">บันทึกทุกครั้งที่ AI พยายามใช้เครื่องมือ รวมครั้งที่ถูกปฏิเสธ แก้ไขหรือลบไม่ได้ เก็บ 1 ปี</p>
        {runs.length === 0 ? (
          <p className="rounded-xl border border-dashed p-6 text-center text-sm text-muted-foreground">ยังไม่มีประวัติ</p>
        ) : (
          <div className="overflow-x-auto rounded-lg border bg-background">
            <table className="w-full text-left text-sm">
              <thead className="bg-muted/60 text-xs">
                <tr>
                  <th scope="col" className="px-3 py-2">เวลา</th>
                  <th scope="col" className="px-3 py-2">เครื่องมือ</th>
                  <th scope="col" className="px-3 py-2">ผล</th>
                  <th scope="col" className="px-3 py-2">แหล่งข้อมูล / เหตุผล</th>
                  <th scope="col" className="px-3 py-2 text-right">ms</th>
                </tr>
              </thead>
              <tbody>
                {runs.map((run) => (
                  <tr key={run.id} className="border-t">
                    <td className="whitespace-nowrap px-3 py-2 text-xs">
                      {new Date(run.created_at).toLocaleString("th-TH", { timeZone: "Asia/Bangkok" })}
                    </td>
                    <td className="px-3 py-2">
                      {run.tool_name}
                      <span className="block text-xs text-muted-foreground">ระดับ {run.permission_level}</span>
                    </td>
                    <td className={cn("px-3 py-2", run.status !== "succeeded" && "text-destructive")}>
                      {STATUS_LABEL[run.status] ?? run.status}
                    </td>
                    <td className="px-3 py-2 text-xs text-muted-foreground">{run.source ?? run.error ?? "—"}</td>
                    <td className="px-3 py-2 text-right tabular-nums">{run.duration_ms ?? "—"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </div>
  );
}

function Stat({ label, value, hint }: { label: string; value: string; hint?: string }) {
  return (
    <div className="rounded-xl border bg-background p-4">
      <p className="text-xs text-muted-foreground">{label}</p>
      <p className="text-2xl font-semibold tabular-nums">{value}</p>
      {hint ? <p className="text-[11px] text-muted-foreground">{hint}</p> : null}
    </div>
  );
}
