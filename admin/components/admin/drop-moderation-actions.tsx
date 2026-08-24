"use client";

import { ActionDialog } from "@/components/admin/action-dialog";
import { removeDrop, restoreDrop } from "@/lib/admin-moderation-actions";

/**
 * Exactly one of Remove/Restore, never both -- a Drop has only 2
 * states ("อยู่"/"ลบแล้ว"), unlike WYN-051's multi-severity user
 * action bar, per the Design spec's Screen 2.
 */
export function DropModerationActions({
  dropId,
  isDeleted,
}: {
  dropId: string;
  isDeleted: boolean;
}) {
  if (isDeleted) {
    return (
      <ActionDialog
        triggerLabel="Restore"
        triggerVariant="default"
        title="กู้คืน Drop"
        confirmLabel="ยืนยันกู้คืน"
        onConfirm={(reason) => restoreDrop({ dropId, reason })}
      />
    );
  }

  return (
    <ActionDialog
      triggerLabel="Remove"
      triggerVariant="destructive"
      title="ลบ Drop"
      description="Drop จะหายไปจากทุกที่ที่ผู้ใช้ทั่วไปเห็นทันที (Home Feed/Search/Profile) เหมือนเจ้าของลบเอง"
      confirmLabel="ยืนยันลบ"
      onConfirm={(reason) => removeDrop({ dropId, reason })}
    />
  );
}
