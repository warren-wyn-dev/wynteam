"use client";

import { useCallback, useEffect, useState } from "react";
import Image from "next/image";
import { useRouter } from "next/navigation";
import type { SupabaseClient } from "@supabase/supabase-js";

import { DeveloperRouteGate } from "@/components/developer-route-gate";
import { AppChrome, EmptyState, LoadingState } from "@/components/phase3-ui";
import { deleteDraft, fetchDrafts, type DraftRow } from "@/lib/drafts";

function relativeLabel(iso: string): string {
  const diffMs = Date.now() - new Date(iso).getTime();
  const minutes = Math.floor(diffMs / 60000);
  if (minutes < 1) return "เมื่อสักครู่";
  if (minutes < 60) return `${minutes} นาทีที่แล้ว`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours} ชั่วโมงที่แล้ว`;
  const days = Math.floor(hours / 24);
  return `${days} วันที่แล้ว`;
}

function draftPreviewText(row: DraftRow): string {
  if (row.poll_options && row.poll_options.length) return row.caption?.trim() ? `โพล: ${row.caption.trim()}` : "โพล (ยังไม่มีคำถาม)";
  if (row.caption?.trim()) return row.caption.trim();
  if (row.image_url) return "รูปภาพ";
  return "ร่างเปล่า";
}

function DraftsInner({ client, userId }: { client: SupabaseClient; userId: string }) {
  const router = useRouter();
  const [rows, setRows] = useState<DraftRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [pendingDelete, setPendingDelete] = useState<DraftRow | null>(null);
  const [deleting, setDeleting] = useState(false);

  const load = useCallback(async () => {
    setLoading(true); setError("");
    try { setRows(await fetchDrafts(client, userId)); }
    catch (e) { setError(e instanceof Error ? e.message : "โหลดร่างไม่สำเร็จ"); }
    finally { setLoading(false); }
  }, [client, userId]);

  useEffect(() => { void load(); }, [load]);

  const confirmDelete = async () => {
    if (!pendingDelete) return;
    setDeleting(true);
    try {
      await deleteDraft(client, pendingDelete.id);
      setRows((current) => current.filter((row) => row.id !== pendingDelete.id));
      setPendingDelete(null);
    } catch (e) { setError(e instanceof Error ? e.message : "ลบร่างไม่สำเร็จ"); }
    finally { setDeleting(false); }
  };

  return (
    <AppChrome title="ร่าง" userId={userId} backHref="/" showBottomNav={false}>
      {error ? <div className="route-empty"><p>{error}</p><button className="route-secondary" type="button" onClick={() => void load()}>ลองใหม่</button></div>
        : loading && !rows.length ? <LoadingState />
        : !rows.length ? <EmptyState>ยังไม่มีร่าง เริ่มเขียนโพสต์แล้วบันทึกไว้ก่อนได้เลย</EmptyState>
        : <div className="drafts-list">
            {rows.map((row) => (
              <div className="drafts-row" key={row.id}>
                <button className="drafts-row-main" type="button" onClick={() => router.push(`/?compose=1&draft=${row.id}`)}>
                  {row.image_url ? <Image src={row.image_url} alt="" width={48} height={48} sizes="48px" /> : <span className="drafts-row-placeholder" aria-hidden="true" />}
                  <span className="drafts-row-copy">
                    <strong>{draftPreviewText(row)}</strong>
                    <small>{relativeLabel(row.updated_at)}</small>
                  </span>
                </button>
                <button className="drafts-row-delete" type="button" aria-label="ลบร่างนี้" onClick={() => setPendingDelete(row)}>ลบ</button>
              </div>
            ))}
          </div>}

      {pendingDelete ? (
        <div className="route-modal-backdrop detail-dialog-backdrop" role="presentation" onClick={() => !deleting && setPendingDelete(null)}>
          <section className="route-modal detail-confirm-dialog" role="alertdialog" aria-modal="true" aria-label="ลบร่างนี้?" onClick={(event) => event.stopPropagation()}>
            <strong>ลบร่างนี้?</strong>
            <p>การลบไม่สามารถย้อนกลับได้</p>
            <footer>
              <button type="button" disabled={deleting} onClick={() => setPendingDelete(null)}>ยกเลิก</button>
              <button className="danger" type="button" disabled={deleting} onClick={() => void confirmDelete()}>{deleting ? <span className="route-system-spinner tiny" /> : "ลบ"}</button>
            </footer>
          </section>
        </div>
      ) : null}
    </AppChrome>
  );
}

export function DraftsRoute() {
  return <DeveloperRouteGate>{({ client, userId }) => <DraftsInner client={client} userId={userId} />}</DeveloperRouteGate>;
}
