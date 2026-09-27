/**
 * Digital Asset Links for the WYNOS Android app (a Trusted Web Activity, see
 * android/README.md). Chrome only opens wynos.online full-screen inside the
 * app — no URL bar — when this statement names the app's package and the
 * SHA-256 fingerprint of the key that signed the installed build.
 *
 * Fingerprints are public (they are read straight off any installed APK), but
 * they are only known once Google Play App Signing / the upload key exist, so
 * they come from ANDROID_TWA_SHA256_FINGERPRINTS (comma separated) rather than
 * being hardcoded. Malformed entries are dropped; none configured → [] (no
 * app is trusted, the app still opens, just with Chrome's URL bar).
 */
export const ANDROID_PACKAGE_NAME = "online.wynos.app";

const FINGERPRINT = /^([0-9A-F]{2}:){31}[0-9A-F]{2}$/;

export function parseFingerprints(raw: string | undefined): string[] {
  if (!raw) return [];
  const seen = new Set<string>();
  for (const part of raw.split(",")) {
    const value = part.trim().toUpperCase();
    if (FINGERPRINT.test(value)) seen.add(value);
  }
  return [...seen];
}

export function assetLinks(raw: string | undefined) {
  const fingerprints = parseFingerprints(raw);
  if (fingerprints.length === 0) return [];
  return [
    {
      relation: ["delegate_permission/common.handle_all_urls"],
      target: {
        namespace: "android_app",
        package_name: ANDROID_PACKAGE_NAME,
        sha256_cert_fingerprints: fingerprints,
      },
    },
  ];
}
