import assert from "node:assert/strict";
import { test } from "node:test";

import { MAX_STEPS, runSecretary, SecretaryRunError } from "../orchestrator.ts";
import { ScriptedProvider, fakeTool, harness, NO_ACCESS } from "./helpers.ts";

const signal = () => new AbortController().signal;
const ask = (text: string) => [{ role: "user" as const, content: text }];

test("plain answer: streams text, sums usage, completes", async () => {
  const provider = new ScriptedProvider([{ blocks: [{ type: "text", text: "สวัสดีครับ" }] }]);
  const h = harness(provider, [fakeTool()]);
  const outcome = await runSecretary({ messages: ask("hi"), tier: "standard", signal: signal() }, h.deps);
  assert.equal(outcome.text, "สวัสดีครับ");
  assert.equal(outcome.ending, "complete");
  assert.deepEqual(outcome.usage, { inputTokens: 100, outputTokens: 50 });
  assert.ok(h.events.some((e) => e.type === "text" && e.delta === "สวัสดีครับ"));
  assert.equal(provider.requests[0].tools.length, 1);
});

test("tool loop: authorizes, runs, audits, wraps output and grounds numbers", async () => {
  const provider = new ScriptedProvider([
    { blocks: [{ type: "tool_use", id: "t1", name: "fake_metric", input: {} }], stopReason: "tool_use" },
    { blocks: [{ type: "text", text: "วันนี้มี 1,234 ออเดอร์" }] },
  ]);
  const h = harness(provider, [fakeTool()]);
  const outcome = await runSecretary({ messages: ask("ยอดวันนี้"), tier: "standard", signal: signal() }, h.deps);

  assert.equal(outcome.ending, "complete");
  assert.deepEqual(outcome.usage, { inputTokens: 200, outputTokens: 100 });
  assert.equal(h.records.length, 1);
  assert.equal(h.records[0].status, "succeeded");
  assert.equal(h.records[0].source, "rpc fake");

  const second = provider.requests[1].messages;
  const toolTurn = second[second.length - 1];
  assert.equal(toolTurn.role, "user");
  const result = Array.isArray(toolTurn.content) ? toolTurn.content[0] : undefined;
  assert.ok(result && result.type === "tool_result" && !result.isError);
  assert.match(result.content, /trust="untrusted"/);

  const statuses = h.events.filter((e) => e.type === "tool").map((e) => (e.type === "tool" ? e.status : ""));
  assert.deepEqual(statuses, ["running", "succeeded"]);
  assert.ok(!h.events.some((e) => e.type === "verification"));
});

test("an invented number is flagged by the grounding check", async () => {
  const provider = new ScriptedProvider([
    { blocks: [{ type: "tool_use", id: "t1", name: "fake_metric", input: {} }], stopReason: "tool_use" },
    { blocks: [{ type: "text", text: "มี 9,999 ออเดอร์" }] },
  ]);
  const h = harness(provider, [fakeTool()]);
  await runSecretary({ messages: ask("q"), tier: "standard", signal: signal() }, h.deps);
  const verification = h.events.find((e) => e.type === "verification");
  assert.deepEqual(verification && verification.type === "verification" && verification.unverifiedNumbers, ["9,999"]);
});

test("a level 2 tool is denied, audited and never run", async () => {
  let ran = false;
  const action = fakeTool({
    name: "refund_order",
    level: 2,
    run: async () => {
      ran = true;
      throw new Error("must not run");
    },
  });
  const provider = new ScriptedProvider([
    { blocks: [{ type: "tool_use", id: "t1", name: "refund_order", input: { order: "x" } }], stopReason: "tool_use" },
    { blocks: [{ type: "text", text: "ต้องให้คนอนุมัติ" }] },
  ]);
  const h = harness(provider, [action]);
  await runSecretary({ messages: ask("refund"), tier: "standard", signal: signal() }, h.deps);
  assert.equal(ran, false);
  assert.equal(h.records[0].status, "denied");
  assert.equal(h.records[0].error, "needs_approval");
  const toolEvent = h.events.find((e) => e.type === "tool");
  assert.ok(toolEvent && toolEvent.type === "tool" && toolEvent.needsApproval === true);
});

test("a tool outside the admin's permissions is denied", async () => {
  const provider = new ScriptedProvider([
    { blocks: [{ type: "tool_use", id: "t1", name: "fake_metric", input: {} }], stopReason: "tool_use" },
    { blocks: [{ type: "text", text: "ไม่มีสิทธิ์" }] },
  ]);
  const h = harness(provider, [fakeTool()], NO_ACCESS);
  await runSecretary({ messages: ask("q"), tier: "standard", signal: signal() }, h.deps);
  assert.equal(h.records[0].status, "denied");
  assert.equal(h.records[0].error, "no_permission");
});

test("an unknown or malformed tool name is denied and recorded under a safe name", async () => {
  const provider = new ScriptedProvider([
    { blocks: [{ type: "tool_use", id: "t1", name: "DROP TABLE;", input: {} }], stopReason: "tool_use" },
    { blocks: [{ type: "text", text: "ok" }] },
  ]);
  const h = harness(provider, [fakeTool()]);
  await runSecretary({ messages: ask("q"), tier: "standard", signal: signal() }, h.deps);
  assert.equal(h.records[0].toolName, "unknown_tool");
  assert.equal(h.records[0].status, "denied");
});

test("invalid tool input is refused before running", async () => {
  let ran = false;
  const tool = fakeTool({
    validate: () => ({ ok: false, error: "bad" }),
    run: async () => {
      ran = true;
      throw new Error("no");
    },
  });
  const provider = new ScriptedProvider([
    { blocks: [{ type: "tool_use", id: "t1", name: "fake_metric", input: { x: 1 } }], stopReason: "tool_use" },
    { blocks: [{ type: "text", text: "ok" }] },
  ]);
  const h = harness(provider, [tool]);
  await runSecretary({ messages: ask("q"), tier: "standard", signal: signal() }, h.deps);
  assert.equal(ran, false);
  assert.equal(h.records[0].status, "failed");
});

test("idempotent tools are retried once on failure", async () => {
  let calls = 0;
  const tool = fakeTool({
    run: async () => {
      calls++;
      if (calls === 1) throw new Error("transient");
      return { data: { n: 1 }, source: { system: "s", reference: "r", window: "w", retrievedAt: "t" } };
    },
  });
  const provider = new ScriptedProvider([
    { blocks: [{ type: "tool_use", id: "t1", name: "fake_metric", input: {} }], stopReason: "tool_use" },
    { blocks: [{ type: "text", text: "ok" }] },
  ]);
  const h = harness(provider, [tool]);
  await runSecretary({ messages: ask("q"), tier: "standard", signal: signal() }, h.deps);
  assert.equal(calls, 2);
  assert.equal(h.records[0].status, "succeeded");
});

test("a slow tool times out without a retry", async () => {
  let calls = 0;
  const tool = fakeTool({
    timeoutMs: 20,
    run: (ctx) => {
      calls++;
      return new Promise((resolve, reject) => ctx.signal.addEventListener("abort", () => reject(new Error("aborted"))));
    },
  });
  const provider = new ScriptedProvider([
    { blocks: [{ type: "tool_use", id: "t1", name: "fake_metric", input: {} }], stopReason: "tool_use" },
    { blocks: [{ type: "text", text: "ok" }] },
  ]);
  const h = harness(provider, [tool]);
  await runSecretary({ messages: ask("q"), tier: "standard", signal: signal() }, h.deps);
  assert.equal(calls, 1);
  assert.equal(h.records[0].status, "timed_out");
});

test("if the audit row cannot be written the tool result is discarded", async () => {
  const provider = new ScriptedProvider([
    { blocks: [{ type: "tool_use", id: "t1", name: "fake_metric", input: {} }], stopReason: "tool_use" },
    { blocks: [{ type: "text", text: "ok" }] },
  ]);
  const h = harness(provider, [fakeTool()]);
  h.deps.recordToolRun = async () => {
    throw new Error("db down");
  };
  await runSecretary({ messages: ask("q"), tier: "standard", signal: signal() }, h.deps);
  const toolTurn = provider.requests[1].messages.at(-1);
  const result = toolTurn && Array.isArray(toolTurn.content) ? toolTurn.content[0] : undefined;
  assert.ok(result && result.type === "tool_result" && result.isError);
  assert.doesNotMatch(result.content, /1234/);
});

test("tool calls cut off at max_tokens are never run", async () => {
  let ran = false;
  const tool = fakeTool({
    run: async () => {
      ran = true;
      throw new Error("no");
    },
  });
  const provider = new ScriptedProvider([
    { blocks: [{ type: "tool_use", id: "t1", name: "fake_metric", input: {} }], stopReason: "max_tokens" },
  ]);
  const h = harness(provider, [tool]);
  const outcome = await runSecretary({ messages: ask("q"), tier: "standard", signal: signal() }, h.deps);
  assert.equal(ran, false);
  assert.equal(outcome.ending, "max_tokens");
});

test("stops after MAX_STEPS tool rounds", async () => {
  const turns = Array.from({ length: MAX_STEPS }, (_, i) => ({
    blocks: [{ type: "tool_use" as const, id: `t${i}`, name: "fake_metric", input: {} }],
    stopReason: "tool_use" as const,
  }));
  const provider = new ScriptedProvider(turns);
  const h = harness(provider, [fakeTool()]);
  const outcome = await runSecretary({ messages: ask("q"), tier: "standard", signal: signal() }, h.deps);
  assert.equal(outcome.ending, "max_steps");
  assert.equal(provider.requests.length, MAX_STEPS);
});

test("a provider failure reports the tokens already spent", async () => {
  const provider = new ScriptedProvider([
    { blocks: [{ type: "tool_use", id: "t1", name: "fake_metric", input: {} }], stopReason: "tool_use" },
    new Error("overloaded"),
  ]);
  const h = harness(provider, [fakeTool()]);
  await assert.rejects(
    runSecretary({ messages: ask("q"), tier: "standard", signal: signal() }, h.deps),
    (error: unknown) => error instanceof SecretaryRunError && error.partial.usage.inputTokens === 100,
  );
});

test("a refusal ends the run with a notice", async () => {
  const provider = new ScriptedProvider([{ blocks: [], stopReason: "refusal" }]);
  const h = harness(provider, [fakeTool()]);
  const outcome = await runSecretary({ messages: ask("q"), tier: "standard", signal: signal() }, h.deps);
  assert.equal(outcome.ending, "refusal");
  assert.ok(h.events.some((e) => e.type === "notice"));
});
