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

## Step 3 developer preview — additional scope

- Native, temporary cart with menu add-on choices: vertical radio buttons for
  single-select (including spicy levels), checkboxes for multi-select,
  quantity and single-store constraints. Prices displayed are **estimates**;
  the checkout button stays disabled.
- Signed-in users can inspect their own order summaries read-only, subject to
  Supabase RLS and an explicit buyer ID filter.
- Test builds from the Android pull request publish an unsigned **debug APK**
  as a short-lived GitHub Actions artifact with **no backend credentials**.
- See `STEP3_QA.md` for staging blocker and release gates.

**Connected GitHub Actions QA debug build:** the CI workflow injects the
public Supabase URL and **publishable (non-secret) API key** of the existing
WYNOS Web project. This is intentional only for the QA debug APK; its
public catalog is already accessible to signed-out website visitors. The
app still cannot place orders or pay. Don't use any service_role or secret
key. Manual Android Studio builds still need local.properties as above.

The connected Stripe Sandbox is missing the food_public_catalog RPC
currently present on WYNOS Web. No live end-to-end login or order test was
performed, and no database schema has been changed. After installing the
updated APK, verify catalog loading and login with a dedicated test account.
Android debug signing certificates can differ between GitHub runners: if
installing an APK reports a signature conflict, uninstall the older beta app
first and then install the new one.
