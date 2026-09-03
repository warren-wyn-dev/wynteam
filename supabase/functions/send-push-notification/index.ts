// WYN-016: Push Notification delivery.
//
// Triggered by a Supabase Database Webhook on `public.notifications`
// INSERT (configured once in the Dashboard by the Founder -- see
// .wyn/docs/design/wyn-016-push-notifications.md for why this isn't a
// SQL trigger in schema.sql). Every one of the 13 existing
// notify_* trigger functions (WYN-012/WYN-015/ZOKY-005) already inserts
// into `notifications` -- this function adds a push-delivery side
// effect on top without touching any of them.
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
  type WebhookPayload,
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

Deno.serve(async (req) => {
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
  // profiles?id=eq.null, same guard clubName/storeName below already use
  // for their own optional foreign keys.
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

  let storeName: string | null = null;
  let messageType = row.type;
  if (row.order_id && row.type === "order_cancelled") {
    // Bidirectional type (see notify_order_cancelled in
    // supabase/schema.sql) -- the recipient of *this specific row*
    // tells us which direction/wording applies: if the recipient is
    // the order's buyer, the seller cancelled (app/'s wording);
    // otherwise the recipient is the seller and the buyer cancelled
    // (seller_app's wording). See _lib.ts's messageFor for the two
    // resulting pseudo-types this resolves to.
    const orderRows = await supabaseRestGet(
      `orders?id=eq.${row.order_id}&select=buyer_id,store:stores(name)`,
    );
    const order = orderRows[0] as
      | { buyer_id: string; store: { name: string } | null }
      | undefined;
    storeName = order?.store?.name ?? null;
    messageType = order?.buyer_id === row.recipient_id
      ? "order_cancelled_buyer"
      : "order_cancelled_seller";
  } else if (row.order_id) {
    const orderRows = await supabaseRestGet(
      `orders?id=eq.${row.order_id}&select=store:stores(name)`,
    );
    const order = orderRows[0] as { store: { name: string } | null } | undefined;
    storeName = order?.store?.name ?? null;
  }

  const body = messageFor(
    messageType,
    actorName,
    clubName,
    storeName,
    row.reason,
    row.moderation_action_type,
  );
  const data = buildDataPayload(row);
  const collapseKey = collapseKeyFor(row);

  const accessToken = await fetchFcmAccessToken(serviceAccount);
  const fcmUrl =
    `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;

  await Promise.all(
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
            notification: { title: "WYN", body },
            data,
            // Beta4 §11.6 (Duplicate Protection). Each platform spells
            // the same idea differently; all three make a redelivery of
            // this exact notification replace the one already on the
            // device instead of stacking a second copy. See
            // collapseKeyFor's doc comment for why a webhook retry made
            // that a real, user-visible duplicate before this.
            webpush: {
              headers: { Topic: collapseKey },
              // Beta4 §11.2: web needs its notification shaped here --
              // FCM's generic `notification` block above does not carry
              // an icon to a browser, and without one the OS shows the
              // browser's own logo rather than WYNOS's.
              notification: {
                title: "WYN",
                body,
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
      if (!response.ok) {
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
      }
    }),
  );

  return new Response("OK", { status: 200 });
});
