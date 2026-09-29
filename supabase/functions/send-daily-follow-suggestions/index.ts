import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import {
  fetchFcmAccessToken,
  isDeadTokenError,
  pushLanguageFrom,
  safeErrorMessage,
  type FcmServiceAccount,
} from "./_lib.ts";

type Claim = {
  delivery_id: string;
  user_id: string;
  profile_ids: string[];
  language_preference: string;
  local_date: string;
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FCM_SERVICE_ACCOUNT = Deno.env.get("FCM_SERVICE_ACCOUNT");

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

async function finish(deliveryId: string, success: boolean, error?: string) {
  await rpc("finish_daily_follow_suggestion", {
    p_delivery_id: deliveryId,
    p_success: success,
    p_error: error ?? null,
  });
}

function copy(langValue: unknown): { title: string; body: string } {
  const lang = pushLanguageFrom(langValue);
  if (lang === "en") {
    return {
      title: "People you may like 👋",
      body: "We picked a few interesting accounts for you today.",
    };
  }
  return {
    title: "คนใหม่ ๆ ที่คุณอาจสนใจ 👋",
    body: "เราเลือกบัญชีที่น่าสนใจมาให้คุณวันนี้",
  };
}

Deno.serve(async (req: Request) => {
  try {
    const cronKey = req.headers.get("x-wynos-cron-key") ?? "";
    const authorized = await rpc<boolean>("verify_daily_follow_suggestion_cron_key", {
      p_key: cronKey,
    });
    if (!authorized) return new Response("Forbidden", { status: 403 });

    const payload = await req.json().catch(() => ({}));
    if (payload?.source !== "pg_cron") return new Response("Ignored", { status: 200 });
    if (!FCM_SERVICE_ACCOUNT) return new Response("FCM not configured", { status: 500 });

    const claims = await rpc<Claim[]>("claim_daily_follow_suggestions", { p_limit: 50 });
    if (!claims.length) return Response.json({ claimed: 0, sent: 0, failed: 0 });

    const serviceAccount = JSON.parse(FCM_SERVICE_ACCOUNT) as FcmServiceAccount;
    const accessToken = await fetchFcmAccessToken(serviceAccount);
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;

    let sent = 0;
    let failed = 0;

    for (const claim of claims) {
      try {
        const tokens = await restGet(
          `push_tokens?user_id=eq.${encodeURIComponent(claim.user_id)}&platform=eq.web&select=token`,
        ) as Array<{ token?: string }>;

        const { title, body } = copy(claim.language_preference);
        let anySuccess = false;
        const errors: string[] = [];

        for (const tokenRow of tokens) {
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
                data: {
                  type: "daily_follow_suggestion",
                  recipient_id: claim.user_id,
                  delivery_id: claim.delivery_id,
                  notification_id: claim.delivery_id,
                  suggestion_count: String(claim.profile_ids.length),
                  push_title: title,
                  push_body: body,
                },
                webpush: {
                  headers: {
                    TTL: "86400",
                    Topic: "wynos_daily_follow",
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

        if (anySuccess) {
          await finish(claim.delivery_id, true);
          sent += 1;
        } else {
          await finish(claim.delivery_id, false, errors.join(", ") || "no_web_token");
          failed += 1;
        }
      } catch (error) {
        await finish(claim.delivery_id, false, safeErrorMessage(error)).catch(() => undefined);
        failed += 1;
      }
    }

    return Response.json({ claimed: claims.length, sent, failed });
  } catch (error) {
    console.error("send-daily-follow-suggestions failed:", safeErrorMessage(error));
    return new Response("Internal error", { status: 500 });
  }
});
