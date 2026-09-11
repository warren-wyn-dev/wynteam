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
  type FcmServiceAccount,
  messageFor,
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

async function dmPreviewForNotification(row: NotificationRow): Promise<string | null> {
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

  const [actorRows, tokenRows] = await Promise.all([
    row.actor_id
      ? supabaseRestGet(`profiles?id=eq.${row.actor_id}&select=username,display_name`)
      : Promise.resolve([]),
    supabaseRestGet(`push_tokens?user_id=eq.${row.recipient_id}&select=token`),
  ]);
  if (tokenRows.length === 0) {
    return new Response("No registered devices", { status: 200 });
  }

  const actor = actorRows[0] as { username: string; display_name: string | null } | undefined;
  const actorName = actor
    ? displayNameOrUsername(actor.display_name, actor.username)
    : "มีคน";

  let clubName: string | null = null;
  if (row.club_id) {
    const clubRows = await supabaseRestGet(`clubs?id=eq.${row.club_id}&select=name`);
    clubName = (clubRows[0] as { name: string } | undefined)?.name ?? null;
  }

  const dmPreview = await dmPreviewForNotification(row);
  const body = messageFor(
    row.type,
    actorName,
    clubName,
    row.reason,
    row.moderation_action_type,
    dmPreview,
  );
  const { title, body: pushBody } = splitPushMessage(body, actorName);
  const data = buildDataPayload(row);
  const collapseKey = collapseKeyFor(row);

  const accessToken = await fetchFcmAccessToken(serviceAccount);
  const fcmUrl =
    `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;

  const outcomes = await Promise.all(
    (tokenRows as { token: string }[]).map(async ({ token }) => {
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
                icon: "/icons/Icon-192.png",
                badge: "/icons/Icon-192.png",
                tag: collapseKey,
              },
            },
            android: { collapse_key: collapseKey },
            apns: { headers: { "apns-collapse-id": collapseKey } },
          },
        }),
      });
      if (response.ok) return "sent";

      const errorBody = await response.json().catch(() => null);
      const status = errorBody?.error?.status as string | undefined;
      if (status === "UNREGISTERED" || status === "NOT_FOUND" || status === "INVALID_ARGUMENT") {
        await deletePushToken(token);
      }
      return `${response.status} ${status ?? "unknown"}`;
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
