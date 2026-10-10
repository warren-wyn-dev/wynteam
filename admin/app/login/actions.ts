"use server";

import { redirect } from "next/navigation";

import { createClient } from "@/lib/supabase/server";

export type SignInResult = {
  error: string | null;
};

/**
 * Server Action backing LoginForm -- runs entirely server-side, so the
 * platform_role check below can never be bypassed by a client that
 * skips a JS redirect (Design spec's explicit requirement). Returns a
 * result object instead of throwing so the form can show either error
 * message inline without a full page navigation on failure.
 */
export async function signIn(formData: FormData): Promise<SignInResult> {
  const email = String(formData.get("email") ?? "");
  const password = String(formData.get("password") ?? "");

  const supabase = await createClient();

  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password,
  });

  if (error || !data.user) {
    // Deliberately generic -- does not distinguish "no such email" from
    // "wrong password" (account enumeration prevention, Design spec's
    // Screen 1 "ไม่ระบุว่าฝั่งไหนผิด").
    return { error: "อีเมลหรือรหัสผ่านไม่ถูกต้อง" };
  }

  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("platform_role")
    .eq("id", data.user.id)
    .single();

  // A missing role/schema, RLS error or unavailable staging backend is NOT
  // equivalent to an invalid password or a denied role. Fail closed, remove
  // the fresh session and give operators a useful but non-sensitive message.
  // PGRST116 is an ordinary no-profile result: that remains access denied.
  if (profileError && profileError.code !== "PGRST116") {
    await supabase.auth.signOut();
    return { error: "ระบบตรวจสอบสิทธิ์ไม่พร้อมใช้งาน กรุณาติดต่อผู้ดูแลระบบ" };
  }

  const role = profile?.platform_role;
  if (role !== "admin" && role !== "moderator") {
    // Sign out immediately -- a `user`-role account must never be left
    // in a signed-in-but-nowhere-to-go state (Design spec's Screen 1,
    // step 3).
    await supabase.auth.signOut();
    return { error: "บัญชีนี้ไม่มีสิทธิ์เข้าใช้งาน WYN Admin" };
  }

  redirect("/");
}
