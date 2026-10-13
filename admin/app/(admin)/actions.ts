"use server";

import { redirect } from "next/navigation";

import { createClient } from "@/lib/supabase/server";

export type SignOutResult = {
  error: string | null;
};

export async function signOutAction(): Promise<SignOutResult> {
  let destination = "/login";
  try {
    const supabase = await createClient();
    const { error } = await supabase.auth.signOut();
    if (error) {
      // The SDK can clear this session even when revoking other devices
      // fails. Inspect local state only to select feedback, never for access.
      const { data, error: sessionError } = await supabase.auth.getSession();
      if (sessionError || data.session !== null) {
        return { error: "ออกจากระบบไม่สำเร็จ กรุณาลองอีกครั้ง" };
      }
      destination = "/login?logout=local";
    }
  } catch {
    return { error: "ออกจากระบบไม่สำเร็จ กรุณาลองอีกครั้ง" };
  }

  // redirect throws; keep it outside the auth error handler.
  redirect(destination);
}
