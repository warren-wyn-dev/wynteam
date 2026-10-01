import type { SupabaseClient } from "@supabase/supabase-js";

import { MIN_SIGNUP_PASSWORD_LENGTH } from "@/lib/signup-password-policy";

export type MerchantIdentityMode = "merchant" | "legacy_social";

export type MerchantIdentity = {
  user_id: string;
  identity_mode: MerchantIdentityMode;
  active: boolean;
};

export async function fetchMerchantIdentity(client: SupabaseClient, userId: string) {
  const { data, error } = await client
    .from("merchant_users")
    .select("user_id,identity_mode,active")
    .eq("user_id", userId)
    .maybeSingle();
  if (error) throw error;
  return (data as MerchantIdentity | null) ?? null;
}

export async function signInMerchantWithEmail(client: SupabaseClient, email: string, password: string) {
  const { data, error } = await client.auth.signInWithPassword({ email, password });
  if (error) throw error;
  if (!data.user) throw new Error("merchant_sign_in_failed");

  const identity = await fetchMerchantIdentity(client, data.user.id);
  if (!identity?.active) {
    await client.auth.signOut();
    throw new Error("not_merchant_account");
  }
  return { ...data, identity };
}

export async function signUpMerchantWithEmail(client: SupabaseClient, email: string, password: string) {
  if (password.length < MIN_SIGNUP_PASSWORD_LENGTH) {
    throw new Error("merchant_password_too_short");
  }

  const { data, error } = await client.auth.signUp({
    email,
    password,
    options: {
      emailRedirectTo: typeof window === "undefined"
        ? undefined
        : `${window.location.origin}/merchant/login?confirmed=1`,
      data: { wynos_account_type: "merchant" },
    },
  });
  if (error) throw error;

  if (data.user && Array.isArray(data.user.identities) && data.user.identities.length === 0) {
    throw new Error("merchant_email_already_used");
  }
  return data;
}

export async function resetMerchantPasswordForEmail(client: SupabaseClient, email: string) {
  const { error } = await client.auth.resetPasswordForEmail(email, {
    redirectTo: typeof window === "undefined"
      ? undefined
      : `${window.location.origin}/merchant/reset-password`,
  });
  if (error) throw error;
}
