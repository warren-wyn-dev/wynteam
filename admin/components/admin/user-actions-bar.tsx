"use client";

import { ActionDialog } from "@/components/admin/action-dialog";
import { BanDialog } from "@/components/admin/ban-dialog";
import { applyUserAction, unbanUser } from "@/lib/admin-user-actions";

export function UserActionsBar({
  userId,
  username,
  isCurrentlyBlocked,
}: {
  userId: string;
  username: string;
  isCurrentlyBlocked: boolean;
}) {
  return (
    <div className="flex flex-wrap gap-2">
      <ActionDialog
        triggerLabel="Warn"
        title="ตักเตือนผู้ใช้"
        confirmLabel="ยืนยันตักเตือน"
        onConfirm={(reason) =>
          applyUserAction({ targetUserId: userId, actionType: "warning", reason })
        }
      />
      <ActionDialog
        triggerLabel="Restrict"
        title="จำกัดสิทธิ์ผู้ใช้ชั่วคราว"
        requireDuration
        confirmLabel="ยืนยัน Restrict"
        onConfirm={(reason, durationDays) =>
          applyUserAction({ targetUserId: userId, actionType: "restrict", reason, durationDays })
        }
      />
      <ActionDialog
        triggerLabel="Suspend"
        title="ระงับบัญชีชั่วคราว"
        requireDuration
        confirmLabel="ยืนยัน Suspend"
        onConfirm={(reason, durationDays) =>
          applyUserAction({ targetUserId: userId, actionType: "suspend", reason, durationDays })
        }
      />
      <BanDialog userId={userId} username={username} />
      <ActionDialog
        triggerLabel="Unban"
        triggerVariant="outline"
        triggerDisabled={!isCurrentlyBlocked}
        title="ยกเลิกการบล็อกผู้ใช้"
        confirmLabel="ยืนยัน Unban"
        onConfirm={(reason) => unbanUser({ targetUserId: userId, reason })}
      />
    </div>
  );
}
