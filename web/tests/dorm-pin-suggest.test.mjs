import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const { DORM_PIN_CONSENT_VERSION, dormPinName, dormPinOffered, inDormPinArea, suggestDormPin, withdrawDormPins } = await import("../lib/dorm-pin-suggest.ts");

const MSU = { latitude: 16.250903, longitude: 103.256132 };
const client = (handler) => { const calls = []; return { calls, async rpc(name, args) { calls.push({ name, args }); return handler(name, args); } }; };

test("the box is offered only with a building name and a pin inside the collecting area", () => {
  assert.equal(dormPinOffered("หอพักธาราทิพย์", MSU), true);
  assert.equal(dormPinOffered("", MSU), false);
  assert.equal(dormPinOffered("ก", MSU), false);
  assert.equal(dormPinOffered(null, MSU), false);
  assert.equal(dormPinOffered("หอพักธาราทิพย์", null), false);
  assert.equal(dormPinOffered("คอนโด A", { latitude: 13.75, longitude: 100.5 }), false, "Bangkok is outside the area");
  assert.equal(inDormPinArea({ latitude: Number.NaN, longitude: 103.2 }), false);
  assert.equal(inDormPinArea({ latitude: 15.5, longitude: 102.8 }), true);
  assert.equal(inDormPinArea({ latitude: 16.9, longitude: 103.2 }), false);
});

test("the name is cleaned the same way the database does it", () => {
  assert.equal(dormPinName("  หอพัก \u0000 ธาราทิพย์\n"), "หอพัก ธาราทิพย์");
  assert.equal(dormPinName("ก".repeat(200)).length, 80);
  assert.equal(dormPinName(" ก "), null);
});

test("an offer sends only the name, the position, no accuracy and the consent version", async () => {
  const c = client(() => ({ data: { status: "recorded" }, error: null }));
  assert.equal(await suggestDormPin(c, { buildingName: " หอพัก ธาราทิพย์ ", location: MSU }), "sent");
  assert.deepEqual(c.calls, [{ name: "dorm_pin_suggest", args: {
    p_name: "หอพัก ธาราทิพย์", p_latitude: MSU.latitude, p_longitude: MSU.longitude, p_accuracy_m: null, p_consent_version: DORM_PIN_CONSENT_VERSION,
  } }]);
  assert.deepEqual(Object.keys(c.calls[0].args).sort(), ["p_accuracy_m", "p_consent_version", "p_latitude", "p_longitude", "p_name"]);
});

test("nothing is sent without a usable name or a pin in the area", async () => {
  const c = client(() => ({ data: null, error: null }));
  assert.equal(await suggestDormPin(c, { buildingName: "", location: MSU }), "skipped");
  assert.equal(await suggestDormPin(c, { buildingName: "หอพัก", location: null }), "skipped");
  assert.equal(await suggestDormPin(c, { buildingName: "หอพัก", location: { latitude: 0, longitude: 0 } }), "skipped");
  assert.equal(c.calls.length, 0);
});

test("a missing database function is 'unavailable', any other error 'failed', and none is thrown", async () => {
  for (const error of [{ code: "PGRST202", message: "x" }, { code: "42883", message: "x" }, { message: "Could not find the function public.dorm_pin_suggest" }]) {
    assert.equal(await suggestDormPin(client(() => ({ data: null, error })), { buildingName: "หอพัก", location: MSU }), "unavailable");
  }
  assert.equal(await suggestDormPin(client(() => ({ data: null, error: { code: "P0001", message: "too many suggestions" } })), { buildingName: "หอพัก", location: MSU }), "failed");
  assert.equal(await suggestDormPin(client(() => { throw new Error("network"); }), { buildingName: "หอพัก", location: MSU }), "failed");
});

test("withdrawing reports how many offers were stopped and never throws", async () => {
  assert.deepEqual(await withdrawDormPins(client(() => ({ data: 2, error: null }))), { result: "done", count: 2 });
  assert.deepEqual(await withdrawDormPins(client(() => ({ data: null, error: null }))), { result: "done", count: 0 });
  assert.deepEqual(await withdrawDormPins(client(() => ({ data: null, error: { code: "PGRST202", message: "x" } }))), { result: "unavailable", count: 0 });
  assert.deepEqual(await withdrawDormPins(client(() => ({ data: null, error: { code: "P0001", message: "x" } }))), { result: "failed", count: 0 });
  assert.deepEqual(await withdrawDormPins(client(() => { throw new Error("x"); })), { result: "failed", count: 0 });
});

test("the app: the box is never pre-ticked, the offer is sent only after the address is saved and only when ticked", () => {
  const source = readFileSync(new URL("../components/food/wynos-food-developer-app.tsx", import.meta.url), "utf8");
  assert.match(source, /const \[shareDormPin, setShareDormPin\] = useState\(false\)/);
  assert.match(source, /onSave\(form, \{ shareDormPin: dormPinChoice && shareDormPin \}\)/);
  const saveAddress = source.slice(source.indexOf("const saveAddress = async"), source.indexOf("const deleteAddress = async"));
  assert.ok(saveAddress.indexOf("saveFoodCustomerAddress(client, draft)") < saveAddress.indexOf("suggestDormPin("), "offer comes after the address is saved");
  assert.match(saveAddress, /extras\?\.shareDormPin \? await suggestDormPin/);
  // the room, floor, name and phone are never part of the offer
  assert.doesNotMatch(saveAddress.slice(saveAddress.indexOf("suggestDormPin(")), /room|floor|recipient|phone|landmark/);
});
