export interface FcmServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
}

export type PushLanguage = "th" | "en";

export function pushLanguageFrom(value: unknown): PushLanguage {
  return value === "en" ? "en" : "th";
}

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

async function buildSignedJwtAssertion(
  serviceAccount: FcmServiceAccount,
  nowSeconds: number,
): Promise<string> {
  const encoder = new TextEncoder();
  const header = base64Url(encoder.encode(JSON.stringify({ alg: "RS256", typ: "JWT" })));
  const claims = base64Url(encoder.encode(JSON.stringify({
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: nowSeconds,
    exp: nowSeconds + 3600,
  })));
  const signingInput = `${header}.${claims}`;
  const signature = await crypto.subtle.sign(
    { name: "RSASSA-PKCS1-v1_5" },
    await importPrivateKey(serviceAccount.private_key),
    encoder.encode(signingInput),
  );
  return `${signingInput}.${base64Url(new Uint8Array(signature))}`;
}

export async function fetchFcmAccessToken(
  serviceAccount: FcmServiceAccount,
): Promise<string> {
  const assertion = await buildSignedJwtAssertion(
    serviceAccount,
    Math.floor(Date.now() / 1000),
  );
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!response.ok) {
    throw new Error(`FCM OAuth2 token request failed: ${response.status}`);
  }
  const json = await response.json();
  return json.access_token as string;
}

export function isDeadTokenError(
  status: string | undefined,
  message: string | undefined,
): boolean {
  if (status === "UNREGISTERED" || status === "NOT_FOUND") return true;
  return status === "INVALID_ARGUMENT" && /registration token/i.test(message ?? "");
}

export function safeErrorMessage(error: unknown): string {
  const name = error instanceof Error ? error.name : "Error";
  const raw = error instanceof Error ? error.message : String(error);
  const scrubbed = raw
    .replace(/-----BEGIN[\s\S]*?-----END[^-]*-----/g, "[pem]")
    .replace(/[A-Za-z0-9+/_-]{40,}={0,2}/g, "[redacted]");
  return `${name}: ${scrubbed}`.slice(0, 300);
}
