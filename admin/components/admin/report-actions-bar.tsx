"use client";

import { ActionDialog } from "@/components/admin/action-dialog";
import { applyModerationAction } from "@/lib/admin-reports-actions";
import type { ReportTargetType } from "@/lib/admin-reports";

const CONTENT_TARGET_TYPES: ReportTargetType[] = [
  "drop_comment",
  "club_post",
  "club_post_comment",
];

/**
 * Generic action bar for the /reports/[id] detail page -- the same 6
 * actions ModerationActionSheet (the Flutter in-app equivalent) offers,
 * calling apply_moderation_action() directly. Remove Content only
 * shown for content-type targets, mirroring the RPC's own existing
 * validation (WYN-029: rejected for 'user'/'club'; there is no
 * meaningful "content" to remove for 'message'/'redrop' either, so
 * both are excluded here too).
 */
export function ReportActionsBar({
  reportId,
  targetType,
}: {
  reportId: string;
  targetType: ReportTargetType;
}) {
  const showRemoveContent = CONTENT_TARGET_TYPES.includes(targetType);

  return (
    <div className="flex flex-wrap gap-2">
      <ActionDialog
        triggerLabel="No Action"
        title="ไม่ดำเนินการ"
        confirmLabel="ยืนยันไม่ดำเนินการ"
        onConfirm={(reason) =>
          applyModerationAction({ reportId, actionType: "no_action", reason })
        }
      />
      <ActionDialog
        triggerLabel="Warn"
        title="ตักเตือนผู้ใช้"
        confirmLabel="ยืนยันตักเตือน"
        onConfirm={(reason) =>
          applyModerationAction({ reportId, actionType: "warning", reason })
        }
      />
      {showRemoveContent ? (
        <ActionDialog
          triggerLabel="Remove Content"
          triggerVariant="destructive"
          title="ลบเนื้อหา"
          confirmLabel="ยืนยันลบ"
          onConfirm={(reason) =>
            applyModerationAction({ reportId, actionType: "remove_content", reason })
          }
        />
      ) : null}
      <ActionDialog
        triggerLabel="Restrict"
        title="จำกัดสิทธิ์ผู้ใช้ชั่วคราว"
        requireDuration
        confirmLabel="ยืนยัน Restrict"
        onConfirm={(reason, durationDays) =>
          applyModerationAction({ reportId, actionType: "restrict", reason, durationDays })
        }
      />
      <ActionDialog
        triggerLabel="Suspend"
        title="ระงับบัญชีชั่วคราว"
        requireDuration
        confirmLabel="ยืนยัน Suspend"
        onConfirm={(reason, durationDays) =>
          applyModerationAction({ reportId, actionType: "suspend", reason, durationDays })
        }
      />
      <ActionDialog
        triggerLabel="Ban"
        triggerVariant="destructive"
        title="แบนผู้ใช้"
        description="การ Ban เป็นการบล็อกถาวร ผู้ใช้จะโพสต์/ทำกิจกรรมใดๆ ไม่ได้อีก จนกว่าจะมีคน Unban"
        confirmLabel="ยืนยัน Ban"
        onConfirm={(reason) =>
          applyModerationAction({ reportId, actionType: "ban", reason })
        }
      />
    </div>
  );
}
