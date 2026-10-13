# WYNOS Food Android (Native) — Step 2 preview

This is an independent Kotlin + Jetpack Compose app at `food-android/`.
Android Social lives at `android/` and is untouched.

**Current scope**
- Real read-only restaurant and menu browsing via the exact `food_public_catalog` Supabase RPC used by WYNOS Food Web signed-out visitors.
- Native email/password sign-in, sign-out, session restoration and password reset using the **same Supabase Auth project** as WYNOS Web.
- The server decides which storefronts are public. A disabled rollout returns an empty catalog.
- Secure defaults: only a public Supabase publishable key, HTTPS and no cleartext, no saved passwords, backups disabled.
- Checkout, order history and payment remain visibly unavailable. No merchant/customer private database reads or writes.

**Developer setup (not yet connected to any deployed Supabase project)**

1. In Android Studio, open `food-android/`.
2. Install Java 17 and Android SDK Platform 36.
3. Add to `food-android/local.properties` (gitignored):

```properties
WYNOS_FOOD_SUPABASE_URL=https://YOUR-PROJECT.supabase.co
WYNOS_FOOD_SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLIC_PUBLISHABLE_KEY
```

Use the **same Supabase project URL and public publishable key** that
`food.wynos.online` uses. Never put an `sb_secret_` or service-role key here.
Those public values are embedded in the APK by design, and RLS/RPC remains the
security boundary.

4. Build/test:

```sh
cd food-android
./gradlew --no-daemon assembleDebug testDebugUnitTest lintDebug
```

5. Use a test WYNOS account to sign in and verify the public catalog (if
enabled). Never make test purchases against live Stripe.

**Limitations**
- No production credentials were read, copied or added to GitHub.
- API contract verified against migration and current web code; *no end-to-end
  live Supabase or user-account testing has been performed in this task*.
- The existing public rollout gate still controls whether stores are visible.
- All work stays on separate GitHub branches / draft PRs pending review.
