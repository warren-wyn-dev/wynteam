"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { KeyRound, Lock, UserPlus } from "lucide-react";

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
import { ADMIN_LEVELS, ADMIN_LEVEL_LABEL, ADMIN_SYSTEM_LABEL, ZOKY_SYSTEMS, type AdminLevel, type ZokySystem } from "@/lib/admin-systems";
import type { ZokyTeamMember } from "@/lib/zoky-team";
import {
  findZokyTeamCandidate,
  grantZokyPermission,
  revokeZokyPermission,
  zokyTeamErrorMessage,
  type ZokyTeamCandidate,
} from "@/lib/zoky-team-actions";

const selectClass = "h-11 w-full rounded-md border bg-background px-3 text-sm";

export function ZokyTeamManager({
  members,
  currentUserId,
  superAdmin,
}: {
  members: ZokyTeamMember[];
  currentUserId: string;
  superAdmin: boolean;
}) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [lookup, setLookup] = useState("");
  const [candidate, setCandidate] = useState<ZokyTeamCandidate | null>(null);
  const [notFound, setNotFound] = useState(false);
  const [target, setTarget] = useState<{ userId: string; username: string | null } | null>(null);
  const [system, setSystem] = useState<ZokySystem>("food");
  const [level, setLevel] = useState<AdminLevel>("view");

  // Mirrors the RPC rule so locked rows don't offer buttons that would fail:
  // only the super admin changes a Lead's rows (a Lead's own included).
  const locked = (member: ZokyTeamMember) => member.isTeamLead && !superAdmin;

  function run(task: () => Promise<void>, fallback: string, after?: () => void) {
    setError(null);
    startTransition(async () => {
      try {
        await task();
        after?.();
        router.refresh();
      } catch (err) {
        setError(zokyTeamErrorMessage(err, fallback));
      }
    });
  }

  function find(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const username = lookup.trim();
    if (!username) return;
    setError(null);
    setNotFound(false);
    setCandidate(null);
    startTransition(async () => {
      try {
        const found = await findZokyTeamCandidate(username);
        setCandidate(found);
        setNotFound(found === null);
      } catch (err) {
        setError(zokyTeamErrorMessage(err, "ค้นหาผู้ใช้ไม่สำเร็จ"));
      }
    });
  }

  function openGrant(userId: string, username: string | null) {
    setTarget({ userId, username });
    setSystem("food");
    setLevel("view");
  }

  function grant() {
    if (!target) return;
    run(() => grantZokyPermission(target.userId, system, level), "ให้สิทธิ์ไม่สำเร็จ", () => {
      setTarget(null);
      setCandidate(null);
      setLookup("");
    });
  }

  function changeLevel(userId: string, s: ZokySystem, next: AdminLevel) {
    run(() => grantZokyPermission(userId, s, next), "เปลี่ยนระดับสิทธิ์ไม่สำเร็จ");
  }

  function revoke(userId: string, username: string | null, s: ZokySystem) {
    if (!window.confirm(`ถอนสิทธิ์ ${ADMIN_SYSTEM_LABEL[s]} ของ @${username ?? "ผู้ใช้"}?`)) return;
    run(() => revokeZokyPermission(userId, s), "ถอนสิทธิ์ไม่สำเร็จ");
  }

  return (
    <div className="flex flex-col gap-6">
      {error ? (
        <p role="alert" className="rounded-lg border border-destructive/40 bg-destructive/10 px-4 py-3 text-sm text-destructive">
          {error}
        </p>
      ) : null}

      <section className="flex flex-col gap-3" aria-labelledby="zoky-team-heading">
        <h3 id="zoky-team-heading" className="text-base font-semibold">สมาชิกทีม ZOKY</h3>
        {members.length === 0 ? (
          <p className="rounded-xl border border-dashed p-8 text-center text-sm text-muted-foreground">
            ยังไม่มีสมาชิก ค้นหาผู้ใช้ด้านล่างเพื่อให้สิทธิ์
          </p>
        ) : (
          <ul className="flex flex-col gap-3">
            {members.map((member) => (
              <li key={member.userId} className="rounded-xl border bg-card p-4">
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <div className="flex min-w-0 flex-wrap items-center gap-2">
                    <p className="truncate font-medium">@{member.username ?? "ไม่ทราบชื่อ"}</p>
                    {member.isTeamLead ? <Badge variant="ink-solid">หัวหน้าทีม</Badge> : null}
                    {member.userId === currentUserId ? <Badge variant="gray-tonal">คุณ</Badge> : null}
                  </div>
                  {locked(member) ? (
                    <span className="inline-flex items-center gap-1 text-xs text-muted-foreground">
                      <Lock className="size-3.5" aria-hidden /> แก้ได้เฉพาะ super admin
                    </span>
                  ) : (
                    <Button variant="outline" size="sm" disabled={pending} onClick={() => openGrant(member.userId, member.username)}>
                      <KeyRound /> เพิ่มสิทธิ์
                    </Button>
                  )}
                </div>
                {member.permissions.length === 0 ? (
                  <p className="mt-3 text-sm text-muted-foreground">ยังไม่มีสิทธิ์ Food หรือ Merchant</p>
                ) : (
                  <ul className="mt-3 divide-y">
                    {member.permissions.map((p) => (
                      <li key={p.system} className="flex flex-col gap-2 py-2 sm:flex-row sm:items-center sm:justify-between">
                        <div className="flex flex-wrap items-center gap-2 text-sm">
                          <span>{ADMIN_SYSTEM_LABEL[p.system]}</span>
                          <Badge variant={p.level === "edit" ? "ink-solid" : "gray-tonal"}>{ADMIN_LEVEL_LABEL[p.level]}</Badge>
                          {p.grantedByUsername ? (
                            <span className="text-xs text-muted-foreground">ให้โดย @{p.grantedByUsername}</span>
                          ) : null}
                        </div>
                        {locked(member) ? null : (
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
                        )}
                      </li>
                    ))}
                  </ul>
                )}
              </li>
            ))}
          </ul>
        )}
      </section>

      <section className="flex flex-col gap-3" aria-labelledby="zoky-add-heading">
        <h3 id="zoky-add-heading" className="text-base font-semibold">เพิ่มสมาชิก</h3>
        <form onSubmit={find} className="flex w-full max-w-md gap-2">
          <input
            value={lookup}
            onChange={(event) => setLookup(event.target.value)}
            placeholder="username ของผู้ใช้ (ตรงตัว)"
            aria-label="username ของผู้ใช้"
            autoComplete="off"
            className="h-11 min-w-0 flex-1 rounded-md border bg-background px-3 text-sm"
          />
          <Button type="submit" variant="outline" disabled={pending || lookup.trim() === ""}>ค้นหา</Button>
        </form>
        <p className="text-xs text-muted-foreground">ค้นหาด้วย username ที่ตรงตัวเท่านั้น</p>
        {notFound ? <p className="text-sm text-muted-foreground" role="status">ไม่พบผู้ใช้ที่มี username นี้</p> : null}
        {candidate ? (
          <div className="flex items-center justify-between gap-3 rounded-xl border bg-card px-4 py-2">
            <div className="min-w-0">
              <p className="truncate text-sm font-medium">@{candidate.username}</p>
              {candidate.displayName ? <p className="truncate text-xs text-muted-foreground">{candidate.displayName}</p> : null}
            </div>
            <Button variant="outline" size="sm" disabled={pending} onClick={() => openGrant(candidate.userId, candidate.username)}>
              <UserPlus /> ให้สิทธิ์
            </Button>
          </div>
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
              <Label htmlFor="zoky-grant-system">ระบบ</Label>
              <select id="zoky-grant-system" className={selectClass} value={system} onChange={(e) => setSystem(e.target.value as ZokySystem)}>
                {ZOKY_SYSTEMS.map((s) => (
                  <option key={s} value={s}>{ADMIN_SYSTEM_LABEL[s]}</option>
                ))}
              </select>
            </div>
            <div className="grid gap-2">
              <Label htmlFor="zoky-grant-level">ระดับ</Label>
              <select id="zoky-grant-level" className={selectClass} value={level} onChange={(e) => setLevel(e.target.value as AdminLevel)}>
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
