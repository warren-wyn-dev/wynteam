// WYN-016: Push Notification delivery.
//
// Triggered by a Supabase Database Webhook on `public.notifications`
// INSERT (configured once in the Dashboard by the Founder -- see
// .wyn/docs/design/wyn-016-push-notifications.md for why this isn't a
// SQL trigger in schema.sql). Every existing notify_* trigger function
// (WYN-012/WYN-015 and others since) already inserts into
// `notifications` -- this function adds a push-delivery side effect on
// top without touching any of them.
//
// Pure logic (message templates, JWT signing, data-payload shaping)
// lives in _lib.ts and has its own unit tests (_lib.test.ts) -- this
// file is deliberately a thin orchestrator so `deno test` doesn't need
// to start an actual server or touch the network to verify that logic.
// The parts that genuinely can't be tested without a real Firebase
// project (an actual FCM send, an actual Supabase REST round-trip) are
// confined to this file -- see .wyn/docs/design/
// wyn-016-push-notifications.md's "Acceptance" section for exactly
// what was/wasn't verifiable this round.
//
// Required secrets (`supabase secrets set ...`, set by the Founder once
// a Firebase project + service account exist):
//   SUPABASE_URL                 -- already present in every Edge
//                                    Function's environment by default.
//   SUPABASE_SERVICE_ROLE_KEY    -- same (default Supabase secret).
//   FCM_SERVICE_ACCOUNT          -- the full JSON contents of a Firebase
//                                    service account key (Project
//                                    Settings -> Service Accounts ->
//                                    Generate new private key).
import {
  buildDataPayload,
  collapseKeyFor,
  displayNameOrUsername,
  fetchFcmAccessToken,
  type FcmServiceAccount,
  messageFor,
  safeErrorMessage,
  splitPushMessage,
  summariseOutcomes,
  type WebhookPayload,
  webPushTopic,
} from "./_lib.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// ---------------------------------------------------------------------
// Supabase REST helpers (service-role key -- bypasses RLS, same as
// every other server-side-only path in this project).
// ---------------------------------------------------------------------
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

  if (payload.table !== "notifications" || payload.type !== "INSERT") {
    return new Response("Ignored", { status: 200 });
  }

  const row = payload.record;

  const serviceAccountRaw = Deno.env.get("FCM_SERVICE_ACCOUNT");
  if (!serviceAccountRaw) {
    // Not configured yet (Founder hasn't set up Firebase) -- succeed
    // silently so the webhook doesn't retry-storm. In-app notification
    // delivery (the `notifications` row itself) already happened via
    // the trigger that fired this webhook, independent of this
    // function entirely.
    return new Response("FCM not configured", { status: 200 });
  }
  const serviceAccount: FcmServiceAccount = JSON.parse(serviceAccountRaw);

  // actor_id is null for moderation_warning/moderation_content_removed/
  // system (WYN-029 fix) -- skip the lookup entirely rather than query
  // profiles?id=eq.null, same guard clubName below already uses
  // for its own optional foreign key.
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

  const body = messageFor(
    row.type,
    actorName,
    clubName,
    row.reason,
    row.moderation_action_type,
  );
  // Who did it becomes the title, what they did becomes the body --
  // see splitPushMessage for why, and for the types that keep "WYN".
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
            // Beta4 §11.6 (Duplicate Protection). Each platform spells
            // the same idea differently; all three make a redelivery of
            // this exact notification replace the one already on the
            // device instead of stacking a second copy. See
            // collapseKeyFor's doc comment for why a webhook retry made
            // that a real, user-visible duplicate before this.
            webpush: {
              // Not `collapseKey`: Web Push caps this header at 32
              // characters and a uuid is 36, which Apple rejects
              // outright. See webPushTopic.
              headers: { Topic: webPushTopic(collapseKey) },
              // Beta4 §11.2: web needs its notification shaped here --
              // FCM's generic `notification` block above does not carry
              // an icon to a browser, and without one the OS shows the
              // browser's own logo rather than WYNOS's.
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
      // Self-cleaning: a token FCM no longer recognizes (app
      // uninstalled, token rotated without us hearing about it yet)
      // should stop being tried on every future notification. Any
      // other failure (rate limit, transient network) is left alone
      // -- deleting on those would be wrong, the token is still good.
      if (status === "UNREGISTERED" || status === "NOT_FOUND" || status === "INVALID_ARGUMENT") {
        await deletePushToken(token);
      }
      return `${response.status} ${status ?? "unknown"}`;
    }),
  );

  // Swallowing a per-token rejection is deliberate -- one dead device
  // must not stop the others -- but reporting only "OK" afterwards made
  // "delivered to everyone" and "rejected by FCM for everyone" the same
  // two characters in net._http_response, which is the only place this
  // is ever observed. The counts and FCM's own status strings are what
  // separate them; tokens are not included, and FCM's status values are
  // a fixed vocabulary (UNREGISTERED, SENDER_ID_MISMATCH, ...), not user
  // data.
  return new Response(summariseOutcomes(outcomes), { status: 200 });
}

// Anything thrown above used to reach the caller as a bare 500 with the
// body "Internal Server Error", which says only that this function is
// where it broke. Since the only caller is a database webhook, that
// string is also the entire record of the failure -- it is what lands
// in net._http_response, and nobody sees anything else.
//
// Returning the reason (scrubbed, see safeErrorMessage) makes a failed
// push diagnosable from the database alone. The status stays 500 so the
// failure keeps counting as a failure.
Deno.serve(async (req) => {
  try {
    return await handleWebhook(req);
  } catch (err) {
    const message = safeErrorMessage(err);
    console.error("send-push-notification failed:", message);
    return new Response(message, { status: 500 });
  }
});
