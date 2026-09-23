import type { SupabaseClient, User } from "@supabase/supabase-js";
import { MIN_SIGNUP_PASSWORD_LENGTH } from "@/lib/signup-password-policy";

export class UsernameTakenError extends Error {}
export class UsernameReservedError extends Error {}
export class EmailAlreadyRegisteredError extends Error {}
export class SignupPasswordTooShortError extends Error {}

export type OnboardingStep = "signup" | "profileOptional";

export type OnboardingState = {
  hasDateOfBirth: boolean;
  username: string | null;
  displayName: string | null;
  avatarUrl: string | null;
  isVerified: boolean;
  hasPassword: boolean;
  completed: boolean;
};

export function onboardingResumeStep(state: OnboardingState): OnboardingStep {
  if (!state.hasDateOfBirth || !state.username || !state.displayName) return "signup";
  return "profileOptional";
}

export const notStartedOnboardingState: OnboardingState = {
  hasDateOfBirth: false,
  username: null,
  displayName: null,
  avatarUrl: null,
  isVerified: false,
  hasPassword: false,
  completed: false,
};

// Mirrors AuthRepository.reservedUsernames (app/lib/features/auth/data/auth_repository.dart) —
// keep both lists in sync. The real enforcement is the `profiles_username_not_reserved`
// check constraint in supabase/schema.sql; this is only a fast client-side first check.
export const reservedUsernames = new Set([
  "admin", "administrator", "support", "help", "wynos", "wyn",
  "official", "root", "api", "moderator", "staff", "security", "system",
  "null", "undefined", "everyone", "here", "channel", "settings",
  "about", "terms", "privacy", "www", "app",
]);

export function isUsernameFormatValid(username: string): boolean {
  return /^[a-z0-9_]{3,20}$/.test(username);
}

export async function isInviteGateEnabled(client: SupabaseClient): Promise<boolean> {
  const result = await client.rpc("is_invite_gate_enabled");
  if (result.error) throw result.error;
  return result.data === true;
}

export async function validateReferralCode(client: SupabaseClient, code: string): Promise<boolean> {
  const result = await client.rpc("validate_referral_code", { p_code: code });
  if (result.error) throw result.error;
  return result.data === true;
}

export async function redeemReferralCode(client: SupabaseClient, code: string): Promise<void> {
  const result = await client.rpc("redeem_referral_code", { p_code: code });
  if (result.error) throw result.error;
}

export function getEmailConfirmationRedirectUrl(): string | undefined {
  return typeof window === "undefined" ? undefined : `${window.location.origin}/auth/callback`;
}

export async function signUpWithEmail(client: SupabaseClient, email: string, password: string) {
  if (password.length < MIN_SIGNUP_PASSWORD_LENGTH) throw new SignupPasswordTooShortError();
  const result = await client.auth.signUp({
    email,
    password,
    options: { emailRedirectTo: getEmailConfirmationRedirectUrl() },
  });
  if (result.error) {
    const message = result.error.message.toLowerCase();
    if (message.includes("already registered") || message.includes("already exists")) {
      throw new EmailAlreadyRegisteredError();
    }
    throw result.error;
  }
  return result.data;
}

export async function signInWithEmail(client: SupabaseClient, email: string, password: string) {
  const result = await client.auth.signInWithPassword({ email, password });
  if (result.error) throw result.error;
  return result.data;
}

export async function resetPasswordForEmail(client: SupabaseClient, email: string): Promise<void> {
  const result = await client.auth.resetPasswordForEmail(email, {
    redirectTo: typeof window !== "undefined" ? `${window.location.origin}/reset-password` : undefined,
  });
  if (result.error) throw result.error;
}

/// True once *any* `profiles` row exists for this user — the only signal
/// that's safe to use for "has this account touched onboarding/the app
/// before". `profile_private.onboarding_completed` is NOT safe for this:
/// every account created before the WYN-002 onboarding flow existed on
/// web (i.e. every current wynos.online user) has no `profile_private`
/// row at all, which would misread as "needs onboarding" and bounce a
/// real, working account into the signup flow. A bare `profiles` row
/// with every column still null already rules that out.
export async function hasProfileRow(client: SupabaseClient, userId: string): Promise<boolean> {
  const result = await client.from("profiles").select("id").eq("id", userId).maybeSingle();
  if (result.error) throw result.error;
  return result.data !== null;
}

export async function isUsernameAvailable(client: SupabaseClient, username: string): Promise<boolean> {
  if (reservedUsernames.has(username.toLowerCase())) return false;
  const result = await client.from("profiles").select("id").eq("username", username).maybeSingle();
  if (result.error) throw result.error;
  return result.data === null;
}

export async function setUsername(client: SupabaseClient, userId: string, username: string): Promise<void> {
  if (reservedUsernames.has(username.toLowerCase())) throw new UsernameReservedError();
  const available = await isUsernameAvailable(client, username);
  if (!available) throw new UsernameTakenError();

  const result = await client.from("profiles").upsert({ id: userId, username });
  if (result.error) {
    if (result.error.code === "23505") throw new UsernameTakenError();
    throw result.error;
  }
}

export async function setDateOfBirth(client: SupabaseClient, userId: string, isoDate: string): Promise<void> {
  const profileResult = await client.from("profiles").upsert({ id: userId });
  if (profileResult.error) throw profileResult.error;
  const privateResult = await client.from("profile_private").upsert({ id: userId, date_of_birth: isoDate });
  if (privateResult.error) throw privateResult.error;
}

export async function setDisplayName(client: SupabaseClient, userId: string, displayName: string): Promise<void> {
  const result = await client.from("profiles").update({ display_name: displayName }).eq("id", userId);
  if (result.error) throw result.error;
}

export async function saveOptionalProfile(
  client: SupabaseClient,
  userId: string,
  updates: { avatarUrl?: string; bio?: string },
): Promise<void> {
  const payload: Record<string, string> = {};
  if (updates.avatarUrl !== undefined) payload.avatar_url = updates.avatarUrl;
  if (updates.bio !== undefined) payload.bio = updates.bio;
  if (Object.keys(payload).length === 0) return;
  const result = await client.from("profiles").update(payload).eq("id", userId);
  if (result.error) throw result.error;
}

export async function completeOnboarding(client: SupabaseClient, userId: string): Promise<void> {
  const result = await client
    .from("profile_private")
    .update({ onboarding_completed: true, onboarding_completed_at: new Date().toISOString() })
    .eq("id", userId);
  if (result.error) throw result.error;
}

export async function fetchOnboardingState(client: SupabaseClient, user: User): Promise<OnboardingState> {
  const result = await client
    .from("profiles")
    .select("username, display_name, avatar_url, is_verified, profile_private(date_of_birth, password_set, onboarding_completed)")
    .eq("id", user.id)
    .maybeSingle();
  if (result.error) throw result.error;
  const row = result.data as {
    username: string | null;
    display_name: string | null;
    avatar_url: string | null;
    is_verified: boolean | null;
    profile_private: { date_of_birth: string | null; password_set: boolean | null; onboarding_completed: boolean | null } | null;
  } | null;
  if (!row) return notStartedOnboardingState;

  const priv = row.profile_private;
  const signedUpWithEmailPassword = user.app_metadata?.provider === "email";

  return {
    hasDateOfBirth: Boolean(priv?.date_of_birth),
    username: row.username,
    displayName: row.display_name,
    avatarUrl: row.avatar_url,
    isVerified: row.is_verified ?? false,
    hasPassword: signedUpWithEmailPassword || Boolean(priv?.password_set),
    completed: priv?.onboarding_completed ?? false,
  };
}
