"use client";

import { Toast, useToast } from "@/components/ui/toast";
import { shareOrCopyLink } from "@/lib/share";

/**
 * WYNOS Web Beta1, item 5: exercises shareOrCopyLink() (web/lib/share.ts)
 * against a real DOM without a Supabase-backed page. The test drives this
 * by stubbing navigator.share / navigator.clipboard.writeText before each
 * click (see tests/browser/share.spec.ts) -- no backend needed since
 * sharing a link never touches Supabase. Test-only, not linked from
 * anywhere in the app.
 */
export function ShareFixture() {
  const { toastMessage, showToast } = useToast();
  return (
    <div>
      <button
        id="share-button"
        type="button"
        onClick={() => void shareOrCopyLink({ title: "WYNOS", text: "ทดสอบ", url: "https://wynos.online/drop/1" }, showToast)}
      >
        แชร์
      </button>
      <Toast message={toastMessage} />
    </div>
  );
}
