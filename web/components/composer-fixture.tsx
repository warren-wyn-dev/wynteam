"use client";

import { useMemo, useState } from "react";
import { Beta4Composer } from "@/components/beta4-composer";
import type { SupabaseClient } from "@supabase/supabase-js";

// Isolated fixture: no real account, network call, or database write.
const result = { data: null, error: null, count: 0 };
const fakeClient = {
  from(table: string) {
    return {
      select() {
        return {
          eq() {
            return {
              maybeSingle: async () => ({
                ...result,
                data: table === "profiles"
                  ? { id: "00000000-0000-4000-8000-000000000001", username: "fixture", display_name: "WYNOS", avatar_url: null, is_verified: false }
                  : null,
              }),
              then: (resolve: (value: typeof result) => void) => Promise.resolve(result).then(resolve),
            };
          },
        };
      },
      insert() {
        return { select: () => ({ single: async () => ({ data: { id: "fixture-draft" }, error: null }) }) };
      },
    };
  },
  storage: {
    from() {
      return {
        upload: async () => ({ error: null }),
        getPublicUrl: () => ({ data: { publicUrl: "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg'/%3E" } }),
      };
    },
  },
} as unknown as SupabaseClient;

export function ComposerFixture() {
  const [open, setOpen] = useState(true);
  const [publishCalls, setPublishCalls] = useState(0);
  const client = useMemo(() => ({
    ...fakeClient,
    rpc: async (name: string) => {
      if (name === "publish_drop") {
        setPublishCalls((count) => count + 1);
        // Hold the fake server response long enough to exercise two real
        // click events before React paints the disabled publishing button.
        await new Promise<void>((resolve) => setTimeout(resolve, 400));
        return { data: "fixture-post-id", error: null };
      }
      if (name === "drop_id_for_publication") return { data: null, error: null };
      return { data: null, error: { message: "Unexpected fixture RPC" } };
    },
  } as unknown as SupabaseClient), []);

  return (
    <>
      <output hidden data-testid="fixture-publish-count">{publishCalls}</output>
      {open
        ? <Beta4Composer client={client} userId="00000000-0000-4000-8000-000000000001" onClose={() => setOpen(false)} onPublished={() => {}} />
        : <div data-testid="composer-closed">ปิดหน้าสร้างโพสต์แล้ว</div>}
    </>
  );
}
