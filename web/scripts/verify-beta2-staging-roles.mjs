// Manual, isolated WYNOS Web Beta 2 authenticated role acceptance checks.
// Read a private manifest from bootstrap-beta2-staging.mjs. Never use real users
// or a production Supabase URL. No admin/service-role key is required here.
import assert from "node:assert/strict";
import { readFileSync, statSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { buildSyntheticPlan } from "./bootstrap-beta2-staging.mjs";

const STAGING_URL = "https://yydgdapzlrjmlrjgijkj.supabase.co";
const UUID = /^[a-f0-9]{8}-[a-f0-9]{4}-[1-8][a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/i;

export function validateRoleQaTarget(env, manifest) {
  if (env.CI && env.CI !== "false") throw new Error("Authenticated staging role QA is manual-only, never CI");
  if (env.CONFIRM_WYNOS_STAGING_ROLE_QA !== "YES") throw new Error("Explicit staging role QA confirmation is required");
  if (![STAGING_URL, STAGING_URL + "/"].includes(env.STAGING_SUPABASE_URL))
    throw new Error("QA must target the exact approved Staging Supabase project, never production");
  if (!env.STAGING_SUPABASE_PUBLISHABLE_KEY?.startsWith("sb_publishable_"))
    throw new Error("A staging publishable key is required; no privileged key may be used");
  if (!manifest || manifest.stagingRef !== "yydgdapzlrjmlrjgijkj"
    || manifest.status !== "complete" || !/^[a-f0-9]{8}$/.test(manifest.suffix ?? ""))
    throw new Error("Only a complete approved staging bootstrap manifest is accepted");
  const expected = buildSyntheticPlan(manifest.suffix);
  if (!Array.isArray(manifest.accounts) || manifest.accounts.length !== expected.length
    || !Array.isArray(manifest.clubs) || manifest.clubs.length !== 2)
    throw new Error("The synthetic role/Club inventory must be complete");
  for (const role of expected) {
    const users = manifest.accounts.filter((account) => account.role === role.role);
    if (users.length !== 1) throw new Error("Unexpected synthetic account role inventory");
    const account = users[0];
    if (account.email !== role.email || account.username !== role.username
      || account.developer !== role.developer || account.clubRole !== role.clubRole
      || !UUID.test(account.id ?? "") || typeof account.password !== "string"
      || account.password.length < 30)
      throw new Error("A synthetic account manifest entry is invalid");
  }
  if (manifest.clubs[0].label !== 1 || manifest.clubs[1].label !== 2
    || !manifest.clubs.every((club) => UUID.test(club.id ?? ""))
    || manifest.clubs[0].id === manifest.clubs[1].id)
    throw new Error("Only the two distinct synthetic bootstrap Clubs are allowed");
  return true;
}

function unwrap(result, step) {
  if (result.error) throw new Error(step + ": " + result.error.message);
  return result.data;
}

async function requireDenied(resultPromise, step) {
  const result = await resultPromise;
  assert.ok(result.error, step + " must be denied by the database");
  console.log("PASS " + step);
}

async function run() {
  if (process.argv.length !== 4 || process.argv[2] !== "--manifest")
    throw new Error("Usage: node scripts/verify-beta2-staging-roles.mjs --manifest /private/path/private-test-credentials.json");
  const file = resolve(process.argv[3]);
  const mode = statSync(file).mode & 0o777;
  if (process.platform !== "win32" && (mode & 0o077) !== 0)
    throw new Error("The private staging manifest must be accessible only to its owner (chmod 600)");
  const manifest = JSON.parse(readFileSync(file, "utf8"));
  validateRoleQaTarget(process.env, manifest);
  const { createClient } = await import("@supabase/supabase-js");
  const makeClient = () => createClient(STAGING_URL, process.env.STAGING_SUPABASE_PUBLISHABLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false, detectSessionInUrl: false },
  });
  const anon = makeClient();
  const clients = {};
  let owner, member, moderator, nondevMember, outsider, nondevOutsider;
  let firstChannel, originalMessage, announcementId = null;
  const firstClub = manifest.clubs[0].id;
  const secondClub = manifest.clubs[1].id;

  try {
    await requireDenied(anon.rpc("club_chat_actions_available"), "anonymous Club Chat readiness RPC");
    await requireDenied(anon.rpc("search_club_channel_messages", {
      p_channel_id: firstClub, p_query: "hello", p_limit: 10,
    }), "anonymous Club Chat search RPC");
    for (const account of manifest.accounts) {
      const client = makeClient();
      const login = unwrap(await client.auth.signInWithPassword({
        email: account.email, password: account.password,
      }), "Sign in synthetic " + account.role);
      assert.equal(login.user?.id, account.id, "Only the manifest's synthetic identity may sign in");
      clients[account.role] = client;
      const ready = unwrap(await client.rpc("club_chat_actions_available"), "Readiness " + account.role);
      assert.equal(ready, account.developer, "Developer gate mismatch for " + account.role);
      console.log("PASS signed-in developer gate: " + account.role);
    }
    owner = clients.developer_owner;
    member = clients.developer_member;
    moderator = clients.developer_moderator;
    nondevMember = clients.nondeveloper_member;
    outsider = clients.developer_outsider;
    nondevOutsider = clients.nondeveloper_outsider;

    async function defaultChannel(clubId) {
      const row = unwrap(await owner.from("club_channels").select("id")
        .eq("club_id", clubId).eq("name", "ทั่วไป").single(), "Synthetic default Club channel");
      assert.ok(UUID.test(row.id));
      return row.id;
    }
    firstChannel = await defaultChannel(firstClub);
    const secondChannel = await defaultChannel(secondClub);
    const seeded = unwrap(await owner.from("club_channel_messages")
      .select("id,content,author_id,pinned_at").eq("channel_id", firstChannel),
    "Read synthetic Club messages");
    assert.ok(seeded.length >= 5, "Expected synthetic messages from the staging bootstrap");
    assert.equal(seeded.filter((row) => row.pinned_at).length, 0,
      "This QA suite needs a fresh unpinned bootstrap fixture");
    const messageByText = (text) => {
      const row = seeded.find((item) => item.content === text);
      assert.ok(row && UUID.test(row.id), "Missing synthetic message: " + text);
      return row;
    };
    originalMessage = messageByText("hello world");
    assert.equal(originalMessage.author_id,
      manifest.accounts.find((a) => a.role === "developer_member").id);
    const pinCandidates = ["hello world", "สวัสดีครับ", "สว", "literal 100% under_score"]
      .map(messageByText);

    async function search(client, channelId, term) {
      return unwrap(await client.rpc("search_club_channel_messages", {
        p_channel_id: channelId, p_query: term, p_limit: 30,
      }), "Search " + term);
    }
    assert.ok((await search(member, firstChannel, "hello"))
      .some((row) => row.id === originalMessage.id), "Approved developer member can search");
    assert.ok((await search(member, firstChannel, "สว"))
      .some((row) => row.content === "สวัสดีครับ"), "Short Thai search must work");
    assert.ok((await search(member, firstChannel, "100%"))
      .some((row) => row.content === "literal 100% under_score"),
    "Search wildcards must be treated literally");
    console.log("PASS approved member, Thai and literal wildcard search");
    await requireDenied(member.rpc("search_club_channel_messages", {
      p_channel_id: secondChannel, p_query: "Private", p_limit: 30,
    }), "cross-Club member search");
    await requireDenied(outsider.rpc("search_club_channel_messages", {
      p_channel_id: firstChannel, p_query: "hello", p_limit: 30,
    }), "developer nonmember search");
    await requireDenied(nondevMember.rpc("search_club_channel_messages", {
      p_channel_id: firstChannel, p_query: "hello", p_limit: 30,
    }), "nondeveloper member search");
    await requireDenied(nondevOutsider.rpc("search_club_channel_messages", {
      p_channel_id: firstChannel, p_query: "hello", p_limit: 30,
    }), "nondeveloper nonmember search");
    await requireDenied(owner.rpc("edit_club_channel_message", {
      p_message_id: originalMessage.id, p_content: "owner cannot edit member's message",
    }), "staff editing someone else's message");
    await requireDenied(member.rpc("set_club_channel_message_pin", {
      p_message_id: originalMessage.id, p_pin: true,
    }), "ordinary member pin");
    await requireDenied(nondevMember.rpc("set_club_channel_message_pin", {
      p_message_id: originalMessage.id, p_pin: true,
    }), "nondeveloper pin");

    for (const row of pinCandidates.slice(0, 3))
      unwrap(await owner.rpc("set_club_channel_message_pin", {
        p_message_id: row.id, p_pin: true,
      }), "Pin synthetic message");
    await requireDenied(owner.rpc("set_club_channel_message_pin", {
      p_message_id: pinCandidates[3].id, p_pin: true,
    }), "fourth pin (three-pin server limit)");
    unwrap(await clients.developer_admin.rpc("set_club_channel_message_pin", {
      p_message_id: pinCandidates[2].id, p_pin: false,
    }), "Admin unpin");
    unwrap(await clients.developer_moderator.rpc("set_club_channel_message_pin", {
      p_message_id: pinCandidates[2].id, p_pin: true,
    }), "Moderator repin");
    const pinState = unwrap(await owner.from("club_channel_messages").select("pinned_at")
      .eq("id", originalMessage.id).single(), "Check pinned edit candidate");
    assert.ok(pinState.pinned_at, "Expected pre-edit pin");
    unwrap(await member.rpc("edit_club_channel_message", {
      p_message_id: originalMessage.id,
      p_content: "Beta2 synthetic editing and unpin " + manifest.suffix,
    }), "Author edit");
    const edited = unwrap(await owner.from("club_channel_messages")
      .select("edited_at,pinned_at,content").eq("id", originalMessage.id).single(),
    "Read edited synthetic message");
    assert.ok(edited.edited_at && edited.pinned_at === null, "Author edit must unpin staff-pinned content");
    console.log("PASS staff pin cap, author edit, automatic unpin");

    await requireDenied(member.rpc("create_club_announcement", {
      p_club_id: firstClub, p_body: "Member must not post",
    }), "ordinary member announcement write");
    await requireDenied(nondevMember.rpc("create_club_announcement", {
      p_club_id: firstClub, p_body: "Nondeveloper must not post",
    }), "nondeveloper announcement write");
    announcementId = unwrap(await moderator.rpc("create_club_announcement", {
      p_club_id: firstClub, p_body: "Synthetic role QA announcement " + manifest.suffix,
    }), "Moderator announcement create");
    assert.ok(UUID.test(announcementId), "Expected newly created announcement");
    const visible = unwrap(await member.from("club_announcements").select("id")
      .eq("id", announcementId), "Developer member announcement read");
    assert.equal(visible.length, 1);
    for (const [label, client] of [
      ["nondeveloper", nondevMember], ["developer outsider", outsider], ["nondeveloper outsider", nondevOutsider],
    ]) {
      const hidden = unwrap(await client.from("club_announcements").select("id")
        .eq("id", announcementId), label + " announcement read");
      assert.equal(hidden.length, 0, label + " must not see private Beta2 announcements");
    }
    unwrap(await moderator.rpc("update_club_announcement", {
      p_announcement_id: announcementId, p_body: "Synthetic role QA updated " + manifest.suffix,
    }), "Author announcement edit");
    unwrap(await owner.rpc("delete_club_announcement", {
      p_announcement_id: announcementId,
    }), "Owner announcement delete");
    announcementId = null;
    console.log("PASS developer-only announcement read/write, outsider denials and staff moderation");
  } finally {
    // Remove temporary changes to seeded synthetic data even if an assertion fails.
    // Account and Club deletion is a separate authorized staging-only cleanup.
    if (owner && announcementId) {
      const result = await owner.rpc("delete_club_announcement", { p_announcement_id: announcementId });
      if (result.error) { console.error("FAIL staging QA announcement cleanup"); process.exitCode = 1; }
    }
    if (owner && firstChannel) {
      const remaining = await owner.from("club_channel_messages").select("id")
        .eq("channel_id", firstChannel).not("pinned_at", "is", null);
      if (remaining.error) { console.error("FAIL staging QA pin cleanup"); process.exitCode = 1; }
      else for (const row of remaining.data ?? []) {
        const result = await owner.rpc("set_club_channel_message_pin", { p_message_id: row.id, p_pin: false });
        if (result.error) { console.error("FAIL staging QA pin cleanup"); process.exitCode = 1; }
      }
    }
    if (member && originalMessage) {
      const current = await member.from("club_channel_messages").select("content")
        .eq("id", originalMessage.id).single();
      if (!current.error && current.data?.content !== originalMessage.content) {
        const restored = await member.rpc("edit_club_channel_message", {
          p_message_id: originalMessage.id, p_content: originalMessage.content,
        });
        if (restored.error) { console.error("FAIL staging QA edit cleanup"); process.exitCode = 1; }
      }
    }
    for (const client of Object.values(clients)) {
      try { await client.auth.signOut({ scope: "local" }); } catch { /* ephemeral test client */ }
    }
  }
  if (process.exitCode) throw new Error("Synthetic staging QA cleanup is incomplete");
  console.log("PASS Staging-only authenticated Club Chat and Club Announcements role QA");
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url))
  run().catch((error) => {
    console.error("FAIL authenticated staging QA: " + (error instanceof Error ? error.message : "Unknown error"));
    process.exitCode = 1;
  });
