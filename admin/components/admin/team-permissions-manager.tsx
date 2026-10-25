"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { KeyRound, UserPlus } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Label } from "@/components/ui/label";
import {
  grantAdminPermission,
  permissionErrorMessage,
  revokeAdminPermission,
  setZokyTeamLead,
} from "@/lib/admin-permissions-actions";
import {
  ADMIN_LEVELS,
  ADMIN_LEVEL_LABEL,
  ADMIN_SYSTEMS,
  ADMIN_SYSTEM_LABEL,
  type AdminLevel,
  type AdminSystem,
} from "@/lib/admin-systems";

export type TeamMember = {
  userId: string;
  username: string | null;
  permissions: Array<{ system: AdminSystem; level: AdminLevel }>;
};

export type GrantCandidate = {
  userId: string;
  username: string;
  displayName: string | null;
};

const selectClass = "h-11 w-full rounded-md border bg-background px-3 text-sm";

export function TeamPermissionsManager({
  members,
  candidates,
  searched,
  zokyLeadIds,
}: {
  members: TeamMember[];
  candidates: GrantCandidate[];
  searched: boolean;
  /** ZOKY-ADMIN-001 Team Leads; null hides the controls until the migration is applied. */
  zokyLeadIds: string[] | null;
}) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [target, setTarget] = useState<{ userId: string; username: string | null } | null>(null);
  const [system, setSystem] = useState<AdminSystem>("social");
  const [level, setLevel] = useState<AdminLevel>("view");

  function run(task: () => Promise<void>, fallback: string, after?: () => void) {
    setError(null);
    startTransition(async () => {
      try {
        await task();
        after?.();
        router.refresh();
      } catch (err) {
        setError(permissionErrorMessage(err, fallback));
      }
    });
  }

  function openGrant(userId: string, username: string | null) {
    setTarget({ userId, username });
    setSystem("social");
    setLevel("view");
  }

  function grant() {
    if (!target) return;
    run(() => grantAdminPermission(target.userId, system, level), "ให้สิทธิ์ไม่สำเร็จ", () => setTarget(null));
  }

  function changeLevel(userId: string, s: AdminSystem, next: AdminLevel) {
    run(() => grantAdminPermission(userId, s, next), "เปลี่ยนระดับสิทธิ์ไม่สำเร็จ");
  }

  function toggleZokyLead(userId: string, username: string | null, enable: boolean) {
    const who = `@${username ?? "ผู้ใช้"}`;
    const question = enable
      ? `แต่งตั้ง ${who} เป็นหัวหน้าทีม ZOKY? หัวหน้าทีมให้/ถอนสิทธิ์ ZOKY Food และ ZOKY Merchant กับผู้อื่นได้เอง`
      : `ถอด ${who} จากหัวหน้าทีม ZOKY? สิทธิ์ที่เคยให้ไว้ยังอยู่จนกว่าจะถอน`;
    if (!window.confirm(question)) return;
    run(() => setZokyTeamLead(userId, enable), enable ? "แต่งตั้งหัวหน้าทีม ZOKY ไม่สำเร็จ" : "ถอดหัวหน้าทีม ZOKY ไม่สำเร็จ");
  }

  function zokyLeadButton(userId: string, username: string | null) {
    if (zokyLeadIds === null) return null;
    const isLead = zokyLeadIds.includes(userId);
    return (
      <Button variant="outline" size="sm" disabled={pending} onClick={() => toggleZokyLead(userId, username, !isLead)}>
        {isLead ? "ถอดหัวหน้าทีม ZOKY" : "ตั้งเป็นหัวหน้าทีม ZOKY"}
      </Button>
    );
  }

  function revoke(userId: string, username: string | null, s: AdminSystem) {
    if (!window.confirm(`ถอนสิทธิ์ ${ADMIN_SYSTEM_LABEL[s]} ของ @${username ?? "ผู้ใช้"}?`)) return;
    run(() => revokeAdminPermission(userId, s), "ถอนสิทธิ์ไม่สำเร็จ");
  }

  return (
    <div className="flex flex-col gap-6">
      {error ? (
        <p role="alert" className="rounded-lg border border-destructive/40 bg-destructive/10 px-4 py-3 text-sm text-destructive">
          {error}
        </p>
      ) : null}

      <section className="flex flex-col gap-3" aria-labelledby="team-members-heading">
        <h3 id="team-members-heading" className="text-base font-semibold">ทีมงานที่มีสิทธิ์</h3>
        {members.length === 0 ? (
          <p className="rounded-xl border border-dashed p-8 text-center text-sm text-muted-foreground">
            ยังไม่มีใครได้รับสิทธิ์ ค้นหาผู้ใช้ด้านล่างเพื่อให้สิทธิ์
          </p>
        ) : (
          <ul className="flex flex-col gap-3">
            {members.map((member) => (
              <li key={member.userId} className="rounded-xl border bg-card p-4">
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <div className="flex flex-wrap items-center gap-2">
                    <p className="font-medium">@{member.username ?? "ไม่ทราบชื่อ"}</p>
                    {zokyLeadIds?.includes(member.userId) ? <Badge variant="ink-solid">หัวหน้าทีม ZOKY</Badge> : null}
                  </div>
                  <div className="flex flex-wrap gap-2">
                    {zokyLeadButton(member.userId, member.username)}
                    <Button variant="outline" size="sm" disabled={pending} onClick={() => openGrant(member.userId, member.username)}>
                      <KeyRound /> เพิ่มสิทธิ์
                    </Button>
                  </div>
                </div>
                {member.permissions.length === 0 ? (
                  <p className="mt-3 text-sm text-muted-foreground">ยังไม่มีสิทธิ์ระบบใด</p>
                ) : null}
                <ul className="mt-3 divide-y">
                  {member.permissions.map((p) => (
                    <li key={p.system} className="flex flex-col gap-2 py-2 sm:flex-row sm:items-center sm:justify-between">
                      <div className="flex items-center gap-2 text-sm">
                        <span>{ADMIN_SYSTEM_LABEL[p.system]}</span>
                        <Badge variant={p.level === "edit" ? "ink-solid" : "gray-tonal"}>{ADMIN_LEVEL_LABEL[p.level]}</Badge>
                      </div>
                      <div className="flex gap-2">
                        <Button
                          variant="outline"
                          size="sm"
                          disabled={pending}
                          onClick={() => changeLevel(member.userId, p.system, p.level === "edit" ? "view" : "edit")}
                        >
                          {p.level === "edit" ? "เปลี่ยนเป็นดูอย่างเดียว" : "เปลี่ยนเป็นแก้ไขได้"}
                        </Button>
                        <Button
                          variant="ghost"
                          size="sm"
                          className="text-destructive"
                          disabled={pending}
                          onClick={() => revoke(member.userId, member.username, p.system)}
                        >
                          ถอนสิทธิ์
                        </Button>
                      </div>
                    </li>
                  ))}
                </ul>
              </li>
            ))}
          </ul>
        )}
      </section>

      <section className="flex flex-col gap-3" aria-labelledby="team-grant-heading">
        <h3 id="team-grant-heading" className="text-base font-semibold">ให้สิทธิ์ผู้ใช้</h3>
        <form action="/team" className="flex w-full max-w-md gap-2">
          <input
            name="q"
            placeholder="ค้นหา username หรือชื่อ"
            aria-label="ค้นหาผู้ใช้"
            className="h-11 min-w-0 flex-1 rounded-md border bg-background px-3 text-sm"
          />
          <Button type="submit" variant="outline">ค้นหา</Button>
        </form>
        {searched && candidates.length === 0 ? (
          <p className="text-sm text-muted-foreground">ไม่พบผู้ใช้</p>
        ) : null}
        {candidates.length > 0 ? (
          <ul className="divide-y rounded-xl border bg-card">
            {candidates.map((c) => (
              <li key={c.userId} className="flex items-center justify-between gap-3 px-4 py-2">
                <div className="min-w-0">
                  <p className="truncate text-sm font-medium">@{c.username}</p>
                  {c.displayName ? <p className="truncate text-xs text-muted-foreground">{c.displayName}</p> : null}
                </div>
                <div className="flex flex-wrap justify-end gap-2">
                  {zokyLeadButton(c.userId, c.username)}
                  <Button variant="outline" size="sm" disabled={pending} onClick={() => openGrant(c.userId, c.username)}>
                    <UserPlus /> ให้สิทธิ์
                  </Button>
                </div>
              </li>
            ))}
          </ul>
        ) : null}
      </section>

      <Dialog open={target !== null} onOpenChange={(open) => (open ? null : setTarget(null))}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>ให้สิทธิ์ @{target?.username ?? "ผู้ใช้"}</DialogTitle>
            <DialogDescription>
              เลือกระบบและระดับสิทธิ์ ถ้าผู้ใช้มีสิทธิ์ระบบนี้อยู่แล้ว ระดับจะถูกเปลี่ยนเป็นค่าที่เลือก ทุกการเปลี่ยนแปลงถูกบันทึกใน Audit Log
            </DialogDescription>
          </DialogHeader>
          <div className="grid gap-4">
            <div className="grid gap-2">
              <Label htmlFor="grant-system">ระบบ</Label>
              <select id="grant-system" className={selectClass} value={system} onChange={(e) => setSystem(e.target.value as AdminSystem)}>
                {ADMIN_SYSTEMS.map((s) => (
                  <option key={s} value={s}>{ADMIN_SYSTEM_LABEL[s]}</option>
                ))}
              </select>
            </div>
            <div className="grid gap-2">
              <Label htmlFor="grant-level">ระดับ</Label>
              <select id="grant-level" className={selectClass} value={level} onChange={(e) => setLevel(e.target.value as AdminLevel)}>
                {ADMIN_LEVELS.map((l) => (
                  <option key={l} value={l}>{ADMIN_LEVEL_LABEL[l]}</option>
                ))}
              </select>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setTarget(null)} disabled={pending}>ยกเลิก</Button>
            <Button onClick={grant} disabled={pending}>ให้สิทธิ์</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
