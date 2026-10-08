import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import {
  fetchFcmAccessToken,
  isDeadTokenError,
  pushLanguageFrom,
  safeErrorMessage,
  type FcmServiceAccount,
} from "./_lib.ts";

type NudgeClaim = {
  delivery_id: string;
  user_id: string;
  kind: "first_post" | "return_post";
  prompt_key: string;
  language_preference: string;
};

type DigestClaim = {
  delivery_id: string;
  user_id: string;
  post_count: number;
  author_count: number;
  latest_drop_id: string;
  latest_author_id: string;
  language_preference: string;
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FCM_SERVICE_ACCOUNT = Deno.env.get("FCM_SERVICE_ACCOUNT");

async function rpc<T>(name: string, body: Record<string, unknown>): Promise<T> {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: {
      apikey: SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
  if (!response.ok) {
    throw new Error(`${name} failed: ${response.status} ${await response.text()}`);
  }
  const text = await response.text();
  return (text ? JSON.parse(text) : null) as T;
}

async function restGet(path: string): Promise<unknown[]> {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    headers: {
      apikey: SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
    },
  });
  if (!response.ok) throw new Error(`REST GET failed: ${response.status}`);
  return await response.json();
}

async function restDelete(path: string): Promise<void> {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    method: "DELETE",
    headers: {
      apikey: SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
    },
  });
  if (!response.ok) throw new Error(`REST DELETE failed: ${response.status}`);
}

function nudgeCopy(kind: NudgeClaim["kind"], langValue: unknown) {
  const lang = pushLanguageFrom(langValue);
  if (lang === "en") {
    return kind === "first_post"
      ? {
          title: "Your first post can be simple 👋",
          body: "Introduce yourself, share your day, or ask a quick question on WYNOS.",
        }
      : {
          title: "Anything you'd like to share today? ✨",
          body: "A short post is enough—share what you're interested in right now.",
        };
  }
  return kind === "first_post"
    ? {
        title: "โพสต์แรกของคุณเริ่มง่าย ๆ 👋",
        body: "แนะนำตัว เล่าเรื่องวันนี้ หรือถามอะไรสั้น ๆ บน WYNOS",
      }
    : {
        title: "วันนี้มีอะไรอยากแชร์ไหม? ✨",
        body: "โพสต์สั้น ๆ ก็ได้ เล่าเรื่องที่คุณกำลังสนใจอยู่",
      };
}

async function digestCopy(claim: DigestClaim) {
  const lang = pushLanguageFrom(claim.language_preference);
  const rows = await restGet(
    `profiles?id=eq.${encodeURIComponent(claim.latest_author_id)}&select=username,display_name&limit=1`,
  ) as Array<{ username?: string; display_name?: string | null }>;
  const author = rows[0];
  const name = author?.display_name?.trim() || (author?.username ? `@${author.username}` : (lang === "en" ? "Someone you follow" : "คนที่คุณติดตาม"));

  if (lang === "en") {
    return claim.author_count > 1
      ? {
          title: "New posts from people you follow 👀",
          body: `${name} and ${claim.author_count - 1} others posted something new on WYNOS.`,
        }
      : {
          title: "A new post from someone you follow 👀",
          body: claim.post_count > 1
            ? `${name} has ${claim.post_count} new posts.`
            : `${name} posted something new on WYNOS.`,
        };
  }

  return claim.author_count > 1
    ? {
        title: "มีโพสต์ใหม่จากคนที่คุณติดตาม 👀",
        body: `${name} และอีก ${claim.author_count - 1} คนมีโพสต์ใหม่บน WYNOS`,
      }
    : {
        title: "มีโพสต์ใหม่จากคนที่คุณติดตาม 👀",
        body: claim.post_count > 1
          ? `${name} มีโพสต์ใหม่ ${claim.post_count} โพสต์`
          : `${name} เพิ่งโพสต์สิ่งใหม่บน WYNOS`,
      };
}

async function sendToWebTokens(
  serviceAccount: FcmServiceAccount,
  accessToken: string,
  userId: string,
  data: Record<string, string>,
  topic: string,
): Promise<{ success: boolean; error?: string }> {
  const tokenRows = await restGet(
    `push_tokens?user_id=eq.${encodeURIComponent(userId)}&platform=eq.web&app=eq.social&select=token`,
  ) as Array<{ token?: string }>;

  if (tokenRows.length === 0) return { success: false, error: "no_web_token" };

  const fcmUrl = `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;
  let anySuccess = false;
  const errors: string[] = [];

  for (const tokenRow of tokenRows) {
    const token = tokenRow.token;
    if (!token) continue;
    const response = await fetch(fcmUrl, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          data,
          webpush: {
            headers: {
              TTL: "21600",
              Topic: topic,
            },
          },
        },
      }),
    });

    if (response.ok) {
      anySuccess = true;
      continue;
    }

    const errorBody = await response.json().catch(() => null);
    const status = errorBody?.error?.status as string | undefined;
    const message = errorBody?.error?.message as string | undefined;
    errors.push(`${response.status} ${status ?? "unknown"}`);
    if (isDeadTokenError(status, message)) {
      await restDelete(`push_tokens?token=eq.${encodeURIComponent(token)}`).catch(() => undefined);
    }
  }

  return anySuccess
    ? { success: true }
    : { success: false, error: errors.join(", ") || "send_failed" };
}

Deno.serve(async (req: Request) => {
  try {
    const cronKey = req.headers.get("x-wynos-cron-key") ?? "";
    const authorized = await rpc<boolean>("verify_posting_activity_cron_key", { p_key: cronKey });
    if (!authorized) return new Response("Forbidden", { status: 403 });

    const payload = await req.json().catch(() => ({}));
    if (payload?.source !== "pg_cron") return new Response("Ignored", { status: 200 });
    if (!FCM_SERVICE_ACCOUNT) return new Response("FCM not configured", { status: 500 });

    const [nudges, digests] = await Promise.all([
      rpc<NudgeClaim[]>("claim_posting_nudges", { p_limit: 30 }),
      rpc<DigestClaim[]>("claim_followed_post_digests", { p_limit: 50 }),
    ]);

    if (nudges.length === 0 && digests.length === 0) {
      return Response.json({ nudges: { claimed: 0, sent: 0, failed: 0 }, digests: { claimed: 0, sent: 0, failed: 0 } });
    }

    const serviceAccount = JSON.parse(FCM_SERVICE_ACCOUNT) as FcmServiceAccount;
    const accessToken = await fetchFcmAccessToken(serviceAccount);

    let nudgeSent = 0;
    let nudgeFailed = 0;
    for (const claim of nudges) {
      try {
        const copy = nudgeCopy(claim.kind, claim.language_preference);
        const outcome = await sendToWebTokens(
          serviceAccount,
          accessToken,
          claim.user_id,
          {
            type: "posting_prompt",
            recipient_id: claim.user_id,
            delivery_id: claim.delivery_id,
            prompt_key: claim.prompt_key,
            push_title: copy.title,
            push_body: copy.body,
          },
          "wynos_posting_prompt",
        );
        await rpc("finish_posting_nudge", {
          p_delivery_id: claim.delivery_id,
          p_success: outcome.success,
          p_error: outcome.error ?? null,
        });
        if (outcome.success) nudgeSent += 1;
        else nudgeFailed += 1;
      } catch (error) {
        await rpc("finish_posting_nudge", {
          p_delivery_id: claim.delivery_id,
          p_success: false,
          p_error: safeErrorMessage(error),
        }).catch(() => undefined);
        nudgeFailed += 1;
      }
    }

    let digestSent = 0;
    let digestFailed = 0;
    for (const claim of digests) {
      try {
        const copy = await digestCopy(claim);
        const outcome = await sendToWebTokens(
          serviceAccount,
          accessToken,
          claim.user_id,
          {
            type: "followed_post_digest",
            recipient_id: claim.user_id,
            delivery_id: claim.delivery_id,
            drop_id: claim.latest_drop_id,
            post_count: String(claim.post_count),
            author_count: String(claim.author_count),
            push_title: copy.title,
            push_body: copy.body,
          },
          "wynos_followed_posts",
        );
        await rpc("finish_followed_post_digest", {
          p_delivery_id: claim.delivery_id,
          p_success: outcome.success,
          p_error: outcome.error ?? null,
        });
        if (outcome.success) digestSent += 1;
        else digestFailed += 1;
      } catch (error) {
        await rpc("finish_followed_post_digest", {
          p_delivery_id: claim.delivery_id,
          p_success: false,
          p_error: safeErrorMessage(error),
        }).catch(() => undefined);
        digestFailed += 1;
      }
    }

    return Response.json({
      nudges: { claimed: nudges.length, sent: nudgeSent, failed: nudgeFailed },
      digests: { claimed: digests.length, sent: digestSent, failed: digestFailed },
    });
  } catch (error) {
    console.error("send-posting-activity failed:", safeErrorMessage(error));
    return new Response("Internal error", { status: 500 });
  }
});
