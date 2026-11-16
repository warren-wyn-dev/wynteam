import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { registerHooks } from "node:module";
import test from "node:test";

// resolve the "@/..." alias used by app code
registerHooks({
  resolve(specifier, context, next) {
    if (specifier.startsWith("@/")) return next(new URL(`../${specifier.slice(2)}.ts`, import.meta.url).href, context);
    return next(specifier, context);
  },
});

const { DORM_PIN_CONSENT_VERSION, dormPinName, dormPinOffered, inDormPinArea, suggestDormPin, withdrawDormPins } = await import("../lib/dorm-pin-suggest.ts");
const { DORM_PIN_CONTACT, DORM_PIN_CONTROLLER, dormPinNoticeComplete } = await import("../lib/dorm-pin-notice.ts");
const NOTICE = { controller: "ผู้ควบคุมทดสอบ", contact: "test@example.org" };

const MSU = { latitude: 16.250903, longitude: 103.256132 };
const client = (handler) => { const calls = []; return { calls, async rpc(name, args) { calls.push({ name, args }); return handler(name, args); } }; };

test("the box is offered only with a building name, a pin inside the collecting area and a complete notice", () => {
  assert.equal(dormPinOffered("หอพักธาราทิพย์", MSU, NOTICE), true);
  assert.equal(dormPinOffered("", MSU, NOTICE), false);
  assert.equal(dormPinOffered("ก", MSU, NOTICE), false);
  assert.equal(dormPinOffered(null, MSU, NOTICE), false);
  assert.equal(dormPinOffered("หอพักธาราทิพย์", null, NOTICE), false);
  assert.equal(dormPinOffered("คอนโด A", { latitude: 13.75, longitude: 100.5 }, NOTICE), false, "Bangkok is outside the area");
  // without the controller and the contact the box is never shown
  assert.equal(dormPinOffered("หอพักธาราทิพย์", MSU, { controller: null, contact: "a@b.c" }), false);
  assert.equal(dormPinOffered("หอพักธาราทิพย์", MSU, { controller: "ก", contact: " " }), false);
  assert.equal(dormPinOffered("หอพักธาราทิพย์", MSU), dormPinNoticeComplete(), "the shipped notice decides");
  assert.equal(DORM_PIN_CONTROLLER, "Norswor Maps");
  assert.equal(DORM_PIN_CONTACT, "WynChat");
  assert.equal(dormPinNoticeComplete(), true, "controller and contact are set, so the box is shown");
  assert.equal(dormPinNoticeComplete(), Boolean(DORM_PIN_CONTROLLER?.trim()) && Boolean(DORM_PIN_CONTACT?.trim()));
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

test("the detail text states the retention and names the controller and contact", () => {
  const source = readFileSync(new URL("../components/food/wynos-food-developer-app.tsx", import.meta.url), "utf8");
  assert.match(source, /เราเก็บข้อมูลนี้จนกว่าคุณจะถอนการแชร์ ข้อเสนอที่ผู้ดูแลไม่รับจะถูกลบภายใน 90 วัน/);
  assert.match(source, /\{DORM_PIN_CONTROLLER\}/);
  assert.match(source, /\{DORM_PIN_CONTACT\}/);
});
