// WYN-016: Push Notification delivery.
//
// Triggered by a Supabase Database Webhook on `public.notifications`
// INSERT. `new_message` rows are transport-only: the general notification
// center filters them out, while this function still uses them to fan DM
// events out to registered devices.
import {
  buildDataPayload,
  collapseKeyFor,
  displayNameOrUsername,
  dmMessagePreview,
  fetchFcmAccessToken,
  isDeadTokenError,
  isMerchantNotificationTest,
  isQuietHourAt,
  isRetryableFcmStatus,
  type FcmServiceAccount,
  messageFor,
  pushPreferenceCategory,
  pushLanguageFrom,
  type PushLanguage,
  safeErrorMessage,
  splitPushMessage,
  summariseOutcomes,
  type NotificationRow,
  type WebhookPayload,
  webPushTopic,
} from "./_lib.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

async function supabaseRestGet(path: string): Promise<unknown[]> {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    headers: {
      apikey: SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
    },
  });
  if (!response.ok) return [];
  return await response.json();
}

async function supabaseRestWrite(
  path: string,
  method: "POST" | "PATCH",
  body: Record<string, unknown>,
  prefer?: string,
): Promise<boolean> {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    method,
    headers: {
      apikey: SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
      "Content-Type": "application/json",
      ...(prefer ? { Prefer: prefer } : {}),
    },
    body: JSON.stringify(body),
  });
  return response.ok;
}

type PreviewPushSettings = {
  push_likes?: boolean;
  push_comments?: boolean;
  push_follows?: boolean;
  push_messages?: boolean;
  push_club?: boolean;
  push_trending?: boolean;
  push_system?: boolean;
  push_quiet_enabled?: boolean;
  push_quiet_start?: string;
  push_quiet_end?: string;
  push_timezone?: string;
};

type WebPushPolicy = {
  allowed: boolean;
  skipReason?: "category_disabled" | "quiet_hours";
};

async function webPushPolicy(row: NotificationRow): Promise<WebPushPolicy> {
  if (isMerchantNotificationTest(row)) return { allowed: true };
  const rows = await supabaseRestGet(
    `notification_settings?user_id=eq.${encodeURIComponent(row.recipient_id)}` +
      "&select=push_likes,push_comments,push_follows,push_messages,push_club,push_trending,push_system,push_quiet_enabled,push_quiet_start,push_quiet_end,push_timezone",
  );
  const prefs = (rows[0] as PreviewPushSettings | undefined) ?? {};
  const category = pushPreferenceCategory(row.type);
  const categoryValue = prefs[`push_${category}` as keyof PreviewPushSettings];
  if (categoryValue === false) {
    return { allowed: false, skipReason: "category_disabled" };
  }
  if (
    prefs.push_quiet_enabled === true &&
    isQuietHourAt(
      new Date(),
      typeof prefs.push_timezone === "string" ? prefs.push_timezone : "UTC",
      typeof prefs.push_quiet_start === "string" ? prefs.push_quiet_start : "22:00",
      typeof prefs.push_quiet_end === "string" ? prefs.push_quiet_end : "08:00",
    )
  ) {
    return { allowed: false, skipReason: "quiet_hours" };
  }
  return { allowed: true };
}

async function upsertDelivery(
  row: NotificationRow,
  token: { id: string; platform: string },
  values: Record<string, unknown>,
): Promise<void> {
  await supabaseRestWrite(
    "notification_push_deliveries?on_conflict=notification_id,token_id",
    "POST",
    {
      notification_id: row.id,
      user_id: row.recipient_id,
      token_id: token.id,
      platform: token.platform,
      ...values,
      updated_at: new Date().toISOString(),
    },
    "resolution=merge-duplicates,return=minimal",
  );
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function authoritativeNotification(
  notificationId: string,
): Promise<NotificationRow | null> {
  const fields = [
    "id", "recipient_id", "actor_id", "type", "drop_id", "pop_id", "club_id",
    "club_post_id", "reason", "moderation_action_id", "moderation_action_type",
    "conversation_id", "created_at",
  ].join(",");
  const rows = await supabaseRestGet(
    `notifications?id=eq.${encodeURIComponent(notificationId)}&select=${fields}`,
  );
  return (rows[0] as NotificationRow | undefined) ?? null;
}

// WYN-189: the recipient's app language. No row, or any read failure, keeps
// the Thai templates every notification used before.
async function recipientLanguage(recipientId: string): Promise<PushLanguage> {
  const rows = await supabaseRestGet(
    `user_preferences?user_id=eq.${encodeURIComponent(recipientId)}&select=language_preference`,
  );
  return pushLanguageFrom((rows[0] as { language_preference?: unknown } | undefined)?.language_preference);
}

async function dmPreviewForNotification(row: NotificationRow, lang: PushLanguage): Promise<string | null> {
  if (
    row.type !== "new_message" || !row.conversation_id || !row.actor_id ||
    !row.created_at
  ) {
    return null;
  }

  // The notification trigger runs AFTER the message insert. Bounding the
  // lookup by this notification's timestamp prevents a later rapid-fire DM
  // from replacing the preview of the message that triggered this webhook.
  const rows = await supabaseRestGet(
    `messages?conversation_id=eq.${encodeURIComponent(row.conversation_id)}` +
      `&sender_id=eq.${encodeURIComponent(row.actor_id)}` +
      `&created_at=lte.${encodeURIComponent(row.created_at)}` +
      `&select=text,image_url,shared_content_type,view_once,created_at` +
      `&order=created_at.desc&limit=1`,
  );
  const message = rows[0] as {
    text: string | null;
    image_url: string | null;
    shared_content_type: string | null;
    view_once: boolean | null;
  } | undefined;
  if (!message) return null;

  return dmMessagePreview(
    message.text,
    message.image_url,
    message.shared_content_type,
    message.view_once === true,
    lang,
  );
}

async function deletePushToken(token: string): Promise<void> {
  await fetch(`${SUPABASE_URL}/rest/v1/push_tokens?token=eq.${encodeURIComponent(token)}`, {
    method: "DELETE",
    headers: {
      apikey: SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
    },
  });
}

async function handleWebhook(req: Request): Promise<Response> {
  let payload: WebhookPayload;
  try {
    payload = await req.json();
  } catch {
    return new Response("Bad request", { status: 400 });
  }

  if (
    payload.schema !== "public" || payload.table !== "notifications" ||
    payload.type !== "INSERT" || typeof payload.record?.id !== "string" ||
    payload.record.id.length === 0
  ) {
    return new Response("Ignored", { status: 200 });
  }

  // Never trust recipient/type/target fields supplied by the webhook caller.
  // Reload the authoritative DB row with service-role access and use only that.
  const row = await authoritativeNotification(payload.record.id);
  if (!row) {
    return new Response("Notification not found", { status: 403 });
  }

  const serviceAccountRaw = Deno.env.get("FCM_SERVICE_ACCOUNT");
  if (!serviceAccountRaw) {
    return new Response("FCM not configured", { status: 200 });
  }
  const serviceAccount: FcmServiceAccount = JSON.parse(serviceAccountRaw);

  const [actorRows, tokenRows, lang, webPolicy] = await Promise.all([
    row.actor_id
      ? supabaseRestGet(`profiles?id=eq.${row.actor_id}&select=username,display_name`)
      : Promise.resolve([]),
    supabaseRestGet(`push_tokens?user_id=eq.${row.recipient_id}&select=id,token,platform`),
    recipientLanguage(row.recipient_id),
    webPushPolicy(row),
  ]);
  if (tokenRows.length === 0) {
    return new Response("No registered devices", { status: 200 });
  }

  const typedTokens = tokenRows as { id: string; token: string; platform: string }[];

  const actor = actorRows[0] as { username: string; display_name: string | null } | undefined;
  const actorName = actor
    ? displayNameOrUsername(actor.display_name, actor.username)
    : lang === "en" ? "Someone" : "มีคน";

  let clubName: string | null = null;
  if (row.club_id) {
    const clubRows = await supabaseRestGet(`clubs?id=eq.${row.club_id}&select=name`);
    clubName = (clubRows[0] as { name: string } | undefined)?.name ?? null;
  }

  const dmPreview = await dmPreviewForNotification(row, lang);
  const body = messageFor(
    row.type,
    actorName,
    clubName,
    row.reason,
    row.moderation_action_type,
    dmPreview,
    lang,
  );
  const { title, body: pushBody } = splitPushMessage(body, actorName);
  const data = buildDataPayload(row);
  const collapseKey = collapseKeyFor(row);

  const accessToken = await fetchFcmAccessToken(serviceAccount);
  const fcmUrl =
    `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;

  const outcomes = await Promise.all(
    typedTokens.map(async ({ id, token, platform }) => {
      // Web Push category preferences, Quiet Hours and bounded retry are GA.
      // Android/iOS keep their existing transport behavior.
      const webPolicyApplies = platform === "web";
      if (webPolicyApplies && !webPolicy.allowed) {
        await upsertDelivery(row, { id, platform }, {
          status: "skipped",
          attempt_count: 0,
          last_error: webPolicy.skipReason ?? "policy",
          next_retry_at: null,
          sent_at: null,
        });
        return "skipped";
      }

      const maxAttempts = webPolicyApplies ? 3 : 1;
      if (webPolicyApplies) {
        await upsertDelivery(row, { id, platform }, {
          status: "pending",
          attempt_count: 0,
          last_error: null,
          next_retry_at: null,
          sent_at: null,
        });
      }

      for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
        const response = await fetch(fcmUrl, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            message: {
              token,
              notification: { title, body: pushBody },
              data,
              webpush: {
                headers: { Topic: webPushTopic(collapseKey) },
                notification: {
                  title,
                  body: pushBody,
                  icon: "/icons/icon-192.png",
                  badge: "/icons/icon-192.png",
                  tag: collapseKey,
                },
              },
              android: { collapse_key: collapseKey },
              apns: { headers: { "apns-collapse-id": collapseKey } },
            },
          }),
        });

        if (response.ok) {
          if (webPolicyApplies) {
            await upsertDelivery(row, { id, platform }, {
              status: "sent",
              attempt_count: attempt,
              last_error: null,
              next_retry_at: null,
              sent_at: new Date().toISOString(),
            });
          }
          return "sent";
        }

        const errorBody = await response.json().catch(() => null);
        const status = errorBody?.error?.status as string | undefined;
        const errorMessage = errorBody?.error?.message as string | undefined;
        if (isDeadTokenError(status, errorMessage)) {
          await deletePushToken(token);
        }

        const summary = `${response.status} ${status ?? "unknown"}`;
        const retry = attempt < maxAttempts && isRetryableFcmStatus(response.status);
        if (webPolicyApplies) {
          await upsertDelivery(row, { id, platform }, {
            status: retry ? "retrying" : "failed",
            attempt_count: attempt,
            last_error: summary.slice(0, 300),
            next_retry_at: retry ? new Date(Date.now() + (attempt === 1 ? 300 : 900)).toISOString() : null,
            sent_at: null,
          });
        }
        if (!retry) return summary;
        await sleep(attempt === 1 ? 300 : 900);
      }
      return "failed";
    }),
  );

  return new Response(summariseOutcomes(outcomes), { status: 200 });
}

Deno.serve(async (req) => {
  try {
    return await handleWebhook(req);
  } catch (err) {
    const message = safeErrorMessage(err);
    console.error("send-push-notification failed:", message);
    return new Response(message, { status: 500 });
  }
});
