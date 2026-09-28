/** The Android app that may open wynos.online share links (App Links). */
export const ANDROID_PACKAGE = "io.wyn.wyn";

const FINGERPRINT = /^([0-9A-F]{2}:){31}[0-9A-F]{2}$/;

/**
 * Digital Asset Links statement for the Android app. `fingerprints` is the
 * ANDROID_APP_SHA256_FINGERPRINTS setting: the SHA-256 certificate fingerprints
 * (Play app signing key, and upload key) separated by commas. Certificate
 * fingerprints are public; anything malformed is dropped, and with none the
 * site claims no app.
 */
export function androidAssetLinks(fingerprints: string | undefined) {
  const valid = [
    ...new Set(
      (fingerprints ?? "")
        .split(",")
        .map((value) => value.trim().toUpperCase())
        .filter((value) => FINGERPRINT.test(value)),
    ),
  ];
  if (valid.length === 0) return [];
  return [
    {
      relation: ["delegate_permission/common.handle_all_urls"],
      target: { namespace: "android_app", package_name: ANDROID_PACKAGE, sha256_cert_fingerprints: valid },
    },
  ];
}
