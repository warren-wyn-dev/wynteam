import "jsr:@supabase/functions-js/edge-runtime.d.ts";

type Claim = { user_id: string; stage: number };
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

function message(stage: number, lang: "th" | "en"): string {
  if (lang === "en") {
    if (stage === 1) return "There’s more to discover on WYNOS 👋 Come back and see what’s new.";
    if (stage === 2) return "Drop by WYNOS again—new posts and people are waiting for you.";
    if (stage === 3) return "WYNOS is still here for you ✨ Pick up where you left off anytime.";
    return "See what’s new on WYNOS ✨ Your feed is ready when you are.";
  }
  if (stage === 1) return "ยังมีอะไรให้ค้นพบอีกเยอะใน WYNOS 👋 กลับมาดูว่ามีอะไรใหม่กัน";
  if (stage === 2) return "แวะกลับมา WYNOS กันไหม? มีโพสต์และผู้คนใหม่ ๆ รอคุณอยู่";
  if (stage === 3) return "WYNOS ยังรอคุณอยู่นะ ✨ กลับมาเริ่มใช้งานต่อได้ทุกเมื่อ";
  return "กลับมาดูว่ามีอะไรใหม่ใน WYNOS ✨ ฟีดของคุณพร้อมแล้ว";
}

function deadToken(status: string | undefined, message: string | undefined): boolean {
  if (status === "UNREGISTERED" || status === "NOT_FOUND") return true;
  return status === "INVALID_ARGUMENT" && /registration token/i.test(message ?? "");
}

async function finish(userId: string, stage: number, success: boolean, error?: string) {
  await rpc("finish_web_reactivation_push", {
    p_user_id: userId,
    p_stage: stage,
    p_success: success,
    p_error: error ?? null,
  });
}

async function stateStillEligible(userId: string, stage: number): Promise<boolean> {
  const rows = await restGet(
    `web_reactivation_state?user_id=eq.${encodeURIComponent(userId)}&select=activated_at,lease_stage&limit=1`,
  );
  const row = rows[0] as { activated_at?: string | null; lease_stage?: number | null } | undefined;
  return Boolean(row && row.activated_at == null && row.lease_stage === stage);
}

Deno.serve(async (req: Request) => {
  try {
    const cronKey = req.headers.get("x-wynos-cron-key") ?? "";
    const cronAuthorized = await rpc<boolean>("verify_web_reactivation_cron_key", { p_key: cronKey });
    if (!cronAuthorized) return new Response("Forbidden", { status: 403 });

    const payload = await req.json().catch(() => ({}));
    if (payload?.source !== "pg_cron") return new Response("Ignored", { status: 200 });
    if (!FCM_SERVICE_ACCOUNT) return new Response("FCM not configured", { status: 500 });

    const claims = await rpc<Claim[]>("claim_web_reactivation_pushes", { p_limit: 50 });
    if (!claims.length) return Response.json({ claimed: 0, sent: 0, failed: 0 });

    const serviceAccount = JSON.parse(FCM_SERVICE_ACCOUNT) as FcmServiceAccount;
    const accessToken = await fetchFcmAccessToken(serviceAccount);
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;

    let sent = 0;
    let failed = 0;

    for (const claim of claims) {
      const userId = claim.user_id;
      const stage = Number(claim.stage);
      if (!userId || !Number.isInteger(stage) || stage < 1) continue;

      if (!(await stateStillEligible(userId, stage))) {
        await finish(userId, stage, false, "activated_or_lease_changed");
        continue;
      }

      const [tokens, prefs] = await Promise.all([
        restGet(
          `push_tokens?user_id=eq.${encodeURIComponent(userId)}&platform=eq.web&select=id,token`,
        ),
        restGet(
          `user_preferences?user_id=eq.${encodeURIComponent(userId)}&select=language_preference&limit=1`,
        ),
      ]);

      const lang = (prefs[0] as { language_preference?: string } | undefined)?.language_preference === "en"
        ? "en"
        : "th";
      const body = message(stage, lang);
      let anySuccess = false;
      const errors: string[] = [];

      for (const raw of tokens) {
        const tokenRow = raw as { id?: string; token?: string };
        if (!tokenRow.token) continue;
        const response = await fetch(fcmUrl, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            message: {
              token: tokenRow.token,
              notification: { title: "WYNOS", body },
              data: {
                type: "web_reactivation",
                recipient_id: userId,
                reactivation_stage: String(stage),
                push_title: "WYNOS",
                push_body: body,
              },
              webpush: {
                headers: { Topic: "wynos_reactivation" },
                notification: {
                  title: "WYNOS",
                  body,
                  icon: "/icons/icon-192.png",
                  badge: "/icons/icon-192.png",
                  tag: "wynos-web-reactivation",
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
          await restDelete(`push_tokens?token=eq.${encodeURIComponent(tokenRow.token)}`);
        }
      }

      if (anySuccess) {
        await finish(userId, stage, true);
        sent += 1;
      } else {
        await finish(userId, stage, false, errors.join(", ") || "no_web_token");
        failed += 1;
      }
    }

    return Response.json({ claimed: claims.length, sent, failed });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("send-web-reactivation failed:", message.slice(0, 300));
    return new Response("Internal error", { status: 500 });
  }
});
