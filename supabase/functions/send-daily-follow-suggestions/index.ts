import "jsr:@supabase/functions-js/edge-runtime.d.ts";

type Claim = { delivery_id: string; user_id: string; profile_ids: string[] };
type FcmServiceAccount = { client_email: string; private_key: string; project_id: string };

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FCM_SERVICE_ACCOUNT = Deno.env.get("FCM_SERVICE_ACCOUNT");

function base64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const pemContents = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  const binaryDer = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    "pkcs8",
    binaryDer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

async function fetchFcmAccessToken(serviceAccount: FcmServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const encoder = new TextEncoder();
  const header = base64Url(encoder.encode(JSON.stringify({ alg: "RS256", typ: "JWT" })));
  const claims = base64Url(encoder.encode(JSON.stringify({
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  })));
  const input = `${header}.${claims}`;
  const signature = await crypto.subtle.sign(
    { name: "RSASSA-PKCS1-v1_5" },
    await importPrivateKey(serviceAccount.private_key),
    encoder.encode(input),
  );
  const assertion = `${input}.${base64Url(new Uint8Array(signature))}`;

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!response.ok) throw new Error(`FCM OAuth failed: ${response.status}`);
  const body = await response.json();
  return body.access_token as string;
}

async function restGet(path: string): Promise<unknown[]> {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    headers: {
      apikey: SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
    },
  });
  if (!response.ok) return [];
  return await response.json();
}

async function restDelete(path: string): Promise<void> {
  await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    method: "DELETE",
    headers: {
      apikey: SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
    },
  });
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
  if (!response.ok) throw new Error(`${name} failed: ${response.status}`);
  const text = await response.text();
  return (text ? JSON.parse(text) : null) as T;
}

function deadToken(status: string | undefined, message: string | undefined): boolean {
  if (status === "UNREGISTERED" || status === "NOT_FOUND") return true;
  return status === "INVALID_ARGUMENT" && /registration token/i.test(message ?? "");
}

async function finish(deliveryId: string, success: boolean, error?: string) {
  await rpc("finish_daily_follow_suggestion_push", {
    p_delivery_id: deliveryId,
    p_success: success,
    p_error: error ?? null,
  });
}

Deno.serve(async (req: Request) => {
  try {
    const cronKey = req.headers.get("x-wynos-cron-key") ?? "";
    const authorized = await rpc<boolean>("verify_daily_follow_suggestion_cron_key", { p_key: cronKey });
    if (!authorized) return new Response("Forbidden", { status: 403 });

    const payload = await req.json().catch(() => ({}));
    if (payload?.source !== "pg_cron") return new Response("Ignored", { status: 200 });
    if (!FCM_SERVICE_ACCOUNT) return new Response("FCM not configured", { status: 500 });

    const claims = await rpc<Claim[]>("claim_daily_follow_suggestion_pushes", { p_limit: 100 });
    if (!claims.length) return Response.json({ claimed: 0, sent: 0, failed: 0 });

    const serviceAccount = JSON.parse(FCM_SERVICE_ACCOUNT) as FcmServiceAccount;
    const accessToken = await fetchFcmAccessToken(serviceAccount);
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;

    let sent = 0;
    let failed = 0;

    for (const claim of claims) {
      const [tokens, prefs] = await Promise.all([
        restGet(`push_tokens?user_id=eq.${encodeURIComponent(claim.user_id)}&platform=eq.web&select=token`),
        restGet(`user_preferences?user_id=eq.${encodeURIComponent(claim.user_id)}&select=language_preference&limit=1`),
      ]);

      const lang = (prefs[0] as { language_preference?: string } | undefined)?.language_preference === "en"
        ? "en"
        : "th";
      const title = lang === "en" ? "People you may want to follow 👋" : "คนใหม่ ๆ ที่คุณอาจสนใจ 👋";
      const body = lang === "en"
        ? "We picked a few accounts you might like today."
        : "เราเลือกบัญชีที่น่าสนใจมาให้คุณวันนี้";

      let anySuccess = false;
      const errors: string[] = [];

      for (const raw of tokens) {
        const token = (raw as { token?: string }).token;
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
              notification: { title, body },
              data: {
                type: "daily_follow_suggestion",
                recipient_id: claim.user_id,
                push_title: title,
                push_body: body,
              },
              webpush: {
                headers: { Topic: "wynos_daily_follow" },
                notification: {
                  title,
                  body,
                  icon: "/icons/icon-192.png",
                  badge: "/icons/icon-192.png",
                  tag: "wynos-daily-follow-suggestions",
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
        const errorMessage = errorBody?.error?.message as string | undefined;
        errors.push(`${response.status} ${status ?? "unknown"}`);
        if (deadToken(status, errorMessage)) {
          await restDelete(`push_tokens?token=eq.${encodeURIComponent(token)}`);
        }
      }

      if (anySuccess) {
        await finish(claim.delivery_id, true);
        sent += 1;
      } else {
        await finish(claim.delivery_id, false, errors.join(", ") || "no_web_token");
        failed += 1;
      }
    }

    return Response.json({ claimed: claims.length, sent, failed });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("send-daily-follow-suggestions failed:", message.slice(0, 300));
    return new Response("Internal error", { status: 500 });
  }
});
