"use client";

import { useState } from "react";
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
  return open
    ? <Beta4Composer client={fakeClient} userId="00000000-0000-4000-8000-000000000001" onClose={() => setOpen(false)} onPublished={() => {}} />
    : <div data-testid="composer-closed">ปิดหน้าสร้างโพสต์แล้ว</div>;
}
