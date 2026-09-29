import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import {
  fetchFcmAccessToken,
  isDeadTokenError,
  isRetryableFcmStatus,
  safeErrorMessage,
  type FcmServiceAccount,
  webPushTopic,
} from "../send-push-notification/_lib.ts";
import {
  reactivationMessage,
  type ReactivationLanguage,
} from "./_lib.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

type ReactivationClaim = {
  user_id: string;
  stage: number;
  language: ReactivationLanguage;
};

type WebPushToken = {
  id: string;
  token: string;
};

function serviceHeaders(): Record<string, string> {
  return {
    apikey: SERVICE_ROLE_KEY,
    Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
    "Content-Type": "application/json",
  };
}

async function rpcRows<T>(
  name: string,
  body: Record<string, unknown>,
): Promise<T[]> {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: serviceHeaders(),
    body: JSON.stringify(body),
  });
  if (!response.ok) {
    throw new Error(`${name} failed with HTTP ${response.status}`);
  }
  return await response.json() as T[];
}

async function rpcValue<T>(
  name: string,
  body: Record<string, unknown>,
): Promise<T> {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: serviceHeaders(),
    body: JSON.stringify(body),
  });
  if (!response.ok) {
    throw new Error(`${name} failed with HTTP ${response.status}`);
  }
  return await response.json() as T;
}

async function rpcVoid(
  name: string,
  body: Record<string, unknown>,
): Promise<void> {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: serviceHeaders(),
    body: JSON.stringify(body),
  });
  if (!response.ok) {
    throw new Error(`${name} failed with HTTP ${response.status}`);
  }
}

async function webTokens(userId: string): Promise<WebPushToken[]> {
  const response = await fetch(
    `${SUPABASE_URL}/rest/v1/push_tokens?user_id=eq.${encodeURIComponent(userId)}&platform=eq.web&select=id,token`,
    { headers: serviceHeaders() },
  );
  if (!response.ok) {
    throw new Error(`push token lookup failed with HTTP ${response.status}`);
  }
  return await response.json() as WebPushToken[];
}

async function deleteDeadToken(token: string): Promise<void> {
  await fetch(
    `${SUPABASE_URL}/rest/v1/push_tokens?token=eq.${encodeURIComponent(token)}`,
    {
      method: "DELETE",
      headers: serviceHeaders(),
    },
  );
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function sendToWebToken(
  accessToken: string,
  serviceAccount: FcmServiceAccount,
  token: string,
  claim: ReactivationClaim,
): Promise<boolean> {
  const message = reactivationMessage(claim.stage, claim.language);
  const collapseTag = `web-reactivation-${claim.user_id}`;
  const data = {
    type: "web_reactivation",
    recipient_id: claim.user_id,
    notification_id: collapseTag,
    reactivation_stage: String(claim.stage),
    push_title: message.title,
    push_body: message.body,
  };
  const fcmUrl =
    `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;

  for (let attempt = 1; attempt <= 3; attempt += 1) {
    const response = await fetch(fcmUrl, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification: {
            title: message.title,
            body: message.body,
          },
          data,
          webpush: {
            headers: {
              Topic: webPushTopic(collapseTag),
            },
            notification: {
              title: message.title,
              body: message.body,
              icon: "/icons/icon-192.png",
              badge: "/icons/icon-192.png",
              tag: collapseTag,
            },
          },
        },
      }),
    });

    if (response.ok) return true;

    const errorBody = await response.json().catch(() => null);
    const status = errorBody?.error?.status as string | undefined;
    const errorMessage = errorBody?.error?.message as string | undefined;

    if (isDeadTokenError(status, errorMessage)) {
      await deleteDeadToken(token);
      return false;
    }

    if (attempt === 3 || !isRetryableFcmStatus(response.status)) {
      return false;
    }
    await sleep(attempt === 1 ? 300 : 900);
  }

  return false;
}

async function processClaim(
  claim: ReactivationClaim,
  accessToken: string,
  serviceAccount: FcmServiceAccount,
): Promise<boolean> {
  const tokens = await webTokens(claim.user_id);
  if (tokens.length === 0) {
    await rpcVoid("complete_web_reactivation", {
      p_user_id: claim.user_id,
      p_sent: false,
    });
    return false;
  }

  const results = await Promise.all(
    tokens.map(({ token }) =>
      sendToWebToken(accessToken, serviceAccount, token, claim)
    ),
  );
  const sent = results.some(Boolean);
  await rpcVoid("complete_web_reactivation", {
    p_user_id: claim.user_id,
    p_sent: sent,
  });
  return sent;
}

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return new Response("Method not allowed", {
        status: 405,
        headers: { Allow: "POST" },
      });
    }

    const cronToken = req.headers.get("x-wynos-cron-token");
    if (!cronToken) {
      return new Response("Unauthorized", { status: 401 });
    }
    const validCronToken = await rpcValue<boolean>(
      "validate_web_reactivation_cron_token",
      { p_token: cronToken },
    );
    if (!validCronToken) {
      return new Response("Unauthorized", { status: 401 });
    }

    // Request payload is intentionally ignored. Recipients, timing, language,
    // and stages are claimed from authoritative database state only.
    const serviceAccountRaw = Deno.env.get("FCM_SERVICE_ACCOUNT");
    if (!serviceAccountRaw) {
      return new Response("FCM not configured", { status: 503 });
    }
    const serviceAccount: FcmServiceAccount = JSON.parse(serviceAccountRaw);
    const accessToken = await fetchFcmAccessToken(serviceAccount);

    const claims = await rpcRows<ReactivationClaim>(
      "claim_due_web_reactivations",
      { p_limit: 50 },
    );
    if (claims.length === 0) {
      return Response.json({ ok: true, claimed: 0, sent: 0, failed: 0 });
    }

    const outcomes = await Promise.all(
      claims.map((claim) => processClaim(claim, accessToken, serviceAccount)),
    );
    const sent = outcomes.filter(Boolean).length;
    return Response.json({
      ok: true,
      claimed: claims.length,
      sent,
      failed: claims.length - sent,
    });
  } catch (error) {
    console.error("send-web-reactivation-push failed:", safeErrorMessage(error));
    return new Response("Internal error", { status: 500 });
  }
});
