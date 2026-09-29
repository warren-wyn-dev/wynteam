import { NextResponse } from "next/server";

type PublicPushConfig = {
  configured: true;
  apiKey: string;
  appId: string;
  messagingSenderId: string;
  projectId: string;
  authDomain?: string;
  storageBucket?: string;
  vapidKey: string;
};

function envConfig(): PublicPushConfig | null {
  const apiKey = process.env.NEXT_PUBLIC_FIREBASE_API_KEY;
  const appId = process.env.NEXT_PUBLIC_FIREBASE_APP_ID;
  const messagingSenderId = process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID;
  const projectId = process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID;
  const authDomain = process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN;
  const storageBucket = process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET;
  const vapidKey = process.env.NEXT_PUBLIC_FIREBASE_VAPID_KEY;

  if (!apiKey || !appId || !messagingSenderId || !projectId || !vapidKey) return null;
  return {
    configured: true,
    apiKey,
    appId,
    messagingSenderId,
    projectId,
    authDomain,
    storageBucket,
    vapidKey,
  };
}

function validBridgeConfig(value: unknown): value is PublicPushConfig {
  if (!value || typeof value !== "object") return false;
  const data = value as Record<string, unknown>;
  return data.configured === true
    && typeof data.apiKey === "string"
    && typeof data.appId === "string"
    && typeof data.messagingSenderId === "string"
    && typeof data.projectId === "string"
    && typeof data.vapidKey === "string"
    && (data.authDomain === undefined || typeof data.authDomain === "string")
    && (data.storageBucket === undefined || typeof data.storageBucket === "string");
}

/**
 * Firebase Web config + VAPID key.
 *
 * Prefer the deployment's Vercel environment. Preview deployments on the
 * Hobby plan can be created without the Firebase public variables though,
 * so use the project's public Supabase bridge as a safe fallback. These
 * Firebase values are public-by-design; no service-role keys or secrets are
 * exposed by this endpoint.
 */
export async function GET() {
  const local = envConfig();
  if (local) return NextResponse.json(local);

  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.SUPABASE_URL;
  if (!supabaseUrl) return NextResponse.json({ configured: false });

  try {
    const response = await fetch(
      `${supabaseUrl.replace(/\/$/, "")}/functions/v1/web-push-config-bridge`,
      {
        method: "GET",
        headers: { Accept: "application/json" },
        next: { revalidate: 300 },
      },
    );
    if (!response.ok) return NextResponse.json({ configured: false });

    const bridged: unknown = await response.json();
    if (!validBridgeConfig(bridged)) return NextResponse.json({ configured: false });

    return NextResponse.json(bridged, {
      headers: {
        "Cache-Control": "public, max-age=300, s-maxage=300",
      },
    });
  } catch {
    return NextResponse.json({ configured: false });
  }
}
