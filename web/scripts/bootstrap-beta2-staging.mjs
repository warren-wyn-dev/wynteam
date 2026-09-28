// Manual, STAGING-ONLY synthetic test fixtures for WYNOS Web Beta 2.
// Never run in CI or use credentials, records or identities from production.
import { randomBytes } from "node:crypto";
import { chmodSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const STAGING_URL = "https://yydgdapzlrjmlrjgijkj.supabase.co";
const TEST_ROLES = [
  ["developer_owner", true, "owner"],
  ["developer_admin", true, "admin"],
  ["developer_moderator", true, "moderator"],
  ["developer_member", true, "member"],
  ["developer_outsider", true, null],
  ["nondeveloper_member", false, "member"],
  ["nondeveloper_outsider", false, null],
];

export function validateBootstrapTarget(env) {
  if (env.CI && env.CI !== "false") throw new Error("Synthetic account bootstrap cannot run in CI");
  if (env.CONFIRM_WYNOS_STAGING_BOOTSTRAP !== "YES") throw new Error("Explicit staging bootstrap confirmation is required");
  if (env.STAGING_SUPABASE_URL !== STAGING_URL && env.STAGING_SUPABASE_URL !== STAGING_URL + "/")
    throw new Error("Bootstrap target must be the exact approved staging project, never production");
  const key = env.STAGING_SUPABASE_SERVICE_ROLE_KEY ?? "";
  if (!key || key.startsWith("sb_publishable_")) throw new Error("A staging-only server secret is required");
  if (!key.startsWith("sb_secret_")) {
    try {
      const claim = JSON.parse(Buffer.from(key.split(".")[1], "base64url").toString("utf8"));
      if (claim.role !== "service_role") throw new Error("not service_role");
    } catch {
      throw new Error("Only a staging server secret or service_role JWT is accepted");
    }
  }
  return true;
}

export function buildSyntheticPlan(suffix) {
  if (!/^[a-f0-9]{8}$/.test(suffix)) throw new Error("Synthetic run suffix must be eight hexadecimal characters");
  return TEST_ROLES.map(([role, developer, clubRole]) => ({
    role, developer, clubRole,
    email: "wynos-beta2-" + suffix + "-" + role + "@staging.example.invalid",
    // Keep handles unique and <=20 chars (same limit as public signup).
    // A full role label would exceed that limit and stop fixture creation.
    username: "qa_" + suffix + "_" + ({
      developer_owner: "d_owner", developer_admin: "d_admin",
      developer_moderator: "d_mod", developer_member: "d_member",
      developer_outsider: "d_out", nondeveloper_member: "n_member",
      nondeveloper_outsider: "n_out",
    })[role],
  }));
}

async function applyStagingFixtures() {
  validateBootstrapTarget(process.env);
  const { createClient } = await import("@supabase/supabase-js");
  const suffix = randomBytes(4).toString("hex");
  const plan = buildSyntheticPlan(suffix);
  const directory = mkdtempSync(join(tmpdir(), "wynos-beta2-staging-"));
  chmodSync(directory, 0o700);
  const manifestPath = join(directory, "private-test-credentials.json");
  const manifest = {
    stagingRef: "yydgdapzlrjmlrjgijkj", suffix, status: "starting",
    accounts: plan.map((person) => ({
      ...person, password: randomBytes(28).toString("base64url") + "Aa1!", id: null,
    })),
    clubs: [],
  };
  const persist = () => writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + "\n", { mode: 0o600 });
  persist(); // Keep a private recovery record even if creation partially fails.
  const admin = createClient(process.env.STAGING_SUPABASE_URL, process.env.STAGING_SUPABASE_SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false, detectSessionInUrl: false },
  });
  const assertOk = (result, label) => {
    if (result.error) throw new Error(label + ": " + result.error.message);
    return result.data;
  };
  try {
    for (const user of manifest.accounts) {
      const data = assertOk(await admin.auth.admin.createUser({
        email: user.email, password: user.password, email_confirm: true,
      }), "Create staging " + user.role);
      if (!data?.user?.id) throw new Error("Staging Auth returned no user ID");
      user.id = data.user.id;
      manifest.status = "accounts-created-partially";
      persist();
    }
    assertOk(await admin.from("profiles").insert(manifest.accounts.map((user) => ({
      id: user.id, username: user.username, display_name: "WYNOS QA " + user.role,
    }))), "Create synthetic profiles");
    assertOk(await admin.from("developer_accounts").insert(manifest.accounts
      .filter((user) => user.developer).map((user) => ({
        user_id: user.id, label: "WYNOS Beta2 synthetic staging QA " + suffix,
      }))), "Whitelist synthetic developer identities");

    const byRole = Object.fromEntries(manifest.accounts.map((user) => [user.role, user]));
    for (const index of [1, 2]) {
      const club = assertOk(await admin.from("clubs").insert({
        name: "WYNOS Beta2 QA " + suffix + " Club " + index,
        description: "Synthetic staging-only data; safe to remove after QA.",
        privacy: "private", owner_id: byRole.developer_owner.id,
      }).select("id").single(), "Create synthetic Club " + index);
      if (!club?.id) throw new Error("Synthetic Club ID missing");
      manifest.clubs.push({ id: club.id, label: index });
      persist();
    }
    const [first, second] = manifest.clubs;
    // The existing Club trigger automatically creates the owner membership and default channel.
    const memberRows = [
      ["developer_admin", "admin"], ["developer_moderator", "moderator"],
      ["developer_member", "member"], ["nondeveloper_member", "member"],
    ].map(([role, clubRole]) => ({ club_id: first.id, user_id: byRole[role].id, role: clubRole, status: "approved" }));
    memberRows.push({ club_id: second.id, user_id: byRole.developer_admin.id, role: "admin", status: "approved" });
    assertOk(await admin.from("club_members").insert(memberRows), "Seed approved synthetic memberships");

    const channel = async (clubId) => {
      const row = assertOk(await admin.from("club_channels").select("id")
        .eq("club_id", clubId).eq("name", "ทั่วไป").single(), "Find trigger-created default channel");
      if (!row?.id) throw new Error("Default channel missing");
      return row.id;
    };
    const channelOne = await channel(first.id);
    const channelTwo = await channel(second.id);
    const messages = [
      "hello world", "สวัสดีครับ", "สว", "literal 100% under_score",
      "Pinned message candidate five",
    ].map((content) => ({
      channel_id: channelOne, author_id: byRole.developer_member.id, content,
    }));
    messages.push({ channel_id: channelTwo, author_id: byRole.developer_owner.id, content: "Private second Club message" });
    assertOk(await admin.from("club_channel_messages").insert(messages), "Seed synthetic Club messages");

    const announcements = Array.from({ length: 26 }, (_, i) => ({
      club_id: first.id, author_id: byRole.developer_moderator.id,
      body: "Synthetic staging QA announcement " + (i + 1),
      created_at: new Date(Date.now() - i * 60000).toISOString(),
    }));
    announcements.push({ club_id: second.id, author_id: byRole.developer_owner.id,
      body: "Second Club isolated announcement", created_at: new Date().toISOString() });
    assertOk(await admin.from("club_announcements").insert(announcements), "Seed synthetic announcement pagination");

    manifest.status = "complete";
    persist();
    console.log("Staging-only synthetic accounts, two private Clubs and fixtures created.");
    console.log("Private credentials and cleanup manifest (do not commit or share): " + manifestPath);
  } catch (error) {
    manifest.status = "partial-failure-needs-manual-cleanup";
    persist();
    console.error("Bootstrap stopped. Review the private manifest for partial staging resources.");
    console.error(error instanceof Error ? error.message : "Unknown bootstrap failure");
    process.exitCode = 1;
  }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  if (process.argv.length !== 3 || process.argv[2] !== "--apply") {
    console.error("Manual staging-only command: node scripts/bootstrap-beta2-staging.mjs --apply");
    process.exitCode = 1;
  } else {
    void applyStagingFixtures();
  }
}
