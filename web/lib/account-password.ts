import { createClient, type SupabaseClient } from "@supabase/supabase-js";

import { MIN_SIGNUP_PASSWORD_LENGTH } from "@/lib/signup-password-policy";

export type AccountPasswordErrorCode =
  | "INVALID_FORM"
  | "ACCOUNT_CHANGED"
  | "NO_EMAIL"
  | "WRONG_PASSWORD"
  | "REAUTHENTICATION_REQUIRED"
  | "UPDATE_FAILED";

export class AccountPasswordError extends Error {
  constructor(public readonly code: AccountPasswordErrorCode) {
    super(code);
    this.name = "AccountPasswordError";
  }
}

/** Validate before any network calls; the Supabase Auth minimum is authoritative too. */
export function validatePasswordChange(current: string, next: string, confirmation: string): string | null {
  if (!current || !next || !confirmation) return "กรุณากรอกรหัสผ่านให้ครบทุกช่อง";
  if (next.length < MIN_SIGNUP_PASSWORD_LENGTH) {
    return `รหัสผ่านใหม่ต้องมีอย่างน้อย ${MIN_SIGNUP_PASSWORD_LENGTH} ตัวอักษร`;
  }
  if (next !== confirmation) return "รหัสผ่านใหม่ทั้งสองช่องไม่ตรงกัน";
  if (current === next) return "รหัสผ่านใหม่ต้องแตกต่างจากรหัสผ่านปัจจุบัน";
  return null;
}

/**
 * Reauthenticate the *same* account with its current password on an isolated,
 * non-persistent Supabase client. Never call signInWithPassword on the app's
 * session client: doing so could replace the currently selected account.
 * Do not accept a user-supplied email as proof of account ownership.
 */
export async function changeAccountPassword(
  client: SupabaseClient,
  expectedUserId: string,
  currentPassword: string,
  newPassword: string,
): Promise<void> {
  if (!currentPassword || newPassword.length < MIN_SIGNUP_PASSWORD_LENGTH || currentPassword === newPassword) {
    throw new AccountPasswordError("INVALID_FORM");
  }

  const original = await client.auth.getUser();
  if (original.error || !original.data.user || original.data.user.id !== expectedUserId) {
    throw new AccountPasswordError("ACCOUNT_CHANGED");
  }
  const email = original.data.user.email;
  if (!email) throw new AccountPasswordError("NO_EMAIL");

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const publishableKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!url || !publishableKey) throw new AccountPasswordError("UPDATE_FAILED");

  const verifier = createClient(url, publishableKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
  });
  const verification = await verifier.auth.signInWithPassword({ email, password: currentPassword });
  if (verification.error || !verification.data.user || verification.data.user.id !== expectedUserId) {
    // OAuth-only accounts cannot supply a current password. They can use the
    // existing email-based recovery flow to set their first password instead.
    throw new AccountPasswordError("WRONG_PASSWORD");
  }

  // Recheck the live account immediately before changing credentials, since
  // the user may switch accounts while the isolated verification is pending.
  const stillCurrent = await client.auth.getUser();
  if (stillCurrent.error || !stillCurrent.data.user ||
      stillCurrent.data.user.id !== expectedUserId || stillCurrent.data.user.email !== email) {
    throw new AccountPasswordError("ACCOUNT_CHANGED");
  }

  const updated = await client.auth.updateUser({ password: newPassword });
  if (updated.error) {
    const code = updated.error.code ?? "";
    if (code === "reauthentication_needed" || code === "reauthentication_required") {
      throw new AccountPasswordError("REAUTHENTICATION_REQUIRED");
    }
    throw new AccountPasswordError("UPDATE_FAILED");
  }
}
