import { Sparkles } from "lucide-react";

import { AiSubnav } from "@/components/ai/ai-subnav";
import { fetchSecretaryStatus } from "@/lib/ai/store";
import { requireAdminRole } from "@/lib/auth";

/**
 * WYN-220 AI Secretary section. Phase 1 is for the super admin only; the
 * check here is for the UI -- every RPC and table re-checks it.
 */
export default async function AiSecretaryLayout({ children }: { children: React.ReactNode }) {
  await requireAdminRole();
  const status = await fetchSecretaryStatus();

  return (
    <div className="flex flex-col gap-4 p-4 md:p-6">
      <header className="flex flex-col gap-3">
        <div aria-hidden className="h-1 w-24 rounded-full bg-gradient-to-r from-rose-400 via-amber-300 via-40% to-violet-500" />
        <div className="flex items-center gap-2">
          <Sparkles className="size-5 text-violet-500" aria-hidden />
          <h2 className="text-xl font-semibold">WYNOS AI Secretary</h2>
          <span className="rounded-full border px-2 py-0.5 text-xs text-muted-foreground">Phase 1 · อ่านและวิเคราะห์</span>
        </div>
        <p className="text-sm text-muted-foreground">
          เลขา AI สำหรับผู้บริหาร: วิเคราะห์ข้อมูลจริงจากระบบ WYNOS พร้อมแหล่งที่มา ทุกการเรียกข้อมูลถูกตรวจสิทธิ์และบันทึกไว้
        </p>
      </header>

      {!status.installed ? (
        <Notice>ยังไม่ได้ติดตั้งฐานข้อมูลของ AI Secretary (migration WYN-220) ใน environment นี้</Notice>
      ) : !status.allowed ? (
        <Notice>AI Secretary ใน Phase 1 ใช้ได้เฉพาะ super admin</Notice>
      ) : (
        <>
          <AiSubnav />
          {children}
        </>
      )}
    </div>
  );
}

function Notice({ children }: { children: React.ReactNode }) {
  return <p className="rounded-xl border border-dashed p-10 text-center text-sm text-muted-foreground">{children}</p>;
}
