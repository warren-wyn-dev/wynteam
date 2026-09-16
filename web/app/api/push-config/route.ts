import { NextResponse } from "next/server";

/**
 * Firebase Web config + VAPID key, read server-side so the same values can
 * feed both the page's client bundle and `public/sw.js` (which cannot read
 * `process.env` itself — see the comment there). These are public-by-design
 * values, the same ones already shipped in the Flutter web build's own
 * `app/web/firebase-messaging-sw.js` (see FIREBASE_WEB_API_KEY etc. in
 * `.github/workflows/deploy-web.yml`) — reuse those exact values here rather
 * than provisioning a second Firebase Web app.
 */
export function GET() {
  const apiKey = process.env.NEXT_PUBLIC_FIREBASE_API_KEY;
  const appId = process.env.NEXT_PUBLIC_FIREBASE_APP_ID;
  const messagingSenderId = process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID;
  const projectId = process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID;
  const authDomain = process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN;
  const storageBucket = process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET;
  const vapidKey = process.env.NEXT_PUBLIC_FIREBASE_VAPID_KEY;

  if (!apiKey || !appId || !messagingSenderId || !projectId || !vapidKey) {
    return NextResponse.json({ configured: false });
  }

  return NextResponse.json({
    configured: true,
    apiKey,
    appId,
    messagingSenderId,
    projectId,
    authDomain,
    storageBucket,
    vapidKey,
  });
}
