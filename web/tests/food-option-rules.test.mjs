import assert from "node:assert/strict";
import { test } from "node:test";
import { foodOptionSelectionBounds, foodOptionSelectionHint, foodMenuSelectionsValid, normalizeFoodMenuOptionGroups } from "../lib/food-option-rules.ts";

const group = (patch = {}) => ({
  id: "toppings", name: "ท็อปปิง", required: false, max_select: 3,
  choices: ["egg", "cheese", "tofu"].map((id) => ({ id, name: id, price: 10 })),
  ...patch,
});
const selection = (...ids) => ids.map((choice_id) => ({ group_id: "toppings", choice_id }));

test("legacy required and optional menus keep their selection defaults", () => {
  assert.deepEqual(foodOptionSelectionBounds(group()), { min: 0, max: 3, valid: true });
  assert.deepEqual(foodOptionSelectionBounds(group({ required: true })), { min: 1, max: 3, valid: true });
  assert.equal(foodMenuSelectionsValid([group()], []), true);
  assert.equal(foodMenuSelectionsValid([group({ required: true })], []), false);
  assert.equal(foodMenuSelectionsValid([group({ required: true })], selection("egg")), true);
  assert.equal(foodOptionSelectionBounds(group({ required: true, min_select: 0 })).min, 1);
});

test("minimum and maximum enforce exact boundaries for multi-choice options", () => {
  const options = [group({ min_select: 2, max_select: 2 })];
  assert.equal(foodMenuSelectionsValid(options, selection("egg")), false);
  assert.equal(foodMenuSelectionsValid(options, selection("egg", "tofu")), true);
  assert.equal(foodMenuSelectionsValid(options, selection("egg", "tofu", "cheese")), false);
});

test("unknown choices/groups and duplicate selections cannot pass cart validation", () => {
  const options = [group()];
  assert.equal(foodMenuSelectionsValid(options, selection("unknown")), false);
  assert.equal(foodMenuSelectionsValid(options, [{ group_id: "unknown", choice_id: "egg" }]), false);
  assert.equal(foodMenuSelectionsValid(options, selection("egg", "egg")), false);
  assert.equal(foodMenuSelectionsValid([group(), group()], selection("egg")), false);
});

test("invalid option bounds fail closed instead of enabling Add to cart", () => {
  for (const patch of [{ min_select: -1 }, { min_select: 1.5 }, { max_select: Number.NaN }, { min_select: 21 }, { min_select: 3, max_select: 2 }]) {
    assert.equal(foodMenuSelectionsValid([group(patch)], selection("egg")), false, JSON.stringify(patch));
  }
});

test("legacy maximums keep their effective cap and integer selection count", () => {
  assert.equal(foodOptionSelectionBounds(group({ max_select: 30 })).max, 20);
  assert.equal(foodOptionSelectionBounds(group({ max_select: 0 })).max, 1);
  assert.equal(foodOptionSelectionBounds(group({ max_select: 1.5 })).max, 1);
  assert.equal(foodMenuSelectionsValid([group({ max_select: 30 })], selection("egg")), true);
  assert.equal(foodMenuSelectionsValid([group({ max_select: 1.5 })], selection("egg", "tofu")), false);
});

test("customer hints distinguish optional, exact and ranged option counts", () => {
  assert.equal(foodOptionSelectionHint({ min: 0, max: 1 }), "เลือกได้สูงสุด 1 รายการ");
  assert.equal(foodOptionSelectionHint({ min: 2, max: 2 }), "เลือก 2 รายการ");
  assert.equal(foodOptionSelectionHint({ min: 2, max: 3 }), "เลือกอย่างน้อย 2 รายการ สูงสุด 3 รายการ");
});

test("menu save writes compatible minimums, trims fields and keeps legacy max above choice count", () => {
  const required = normalizeFoodMenuOptionGroups([group({ required: true, name: "  Toppings  " })])[0];
  assert.equal(required.name, "Toppings");
  assert.equal(required.min_select, 1);
  assert.equal(required.required, true);
  const optional = normalizeFoodMenuOptionGroups([group({ choices: [{ id: "egg", name: "egg", price: "10" }], max_select: 20 })])[0];
  assert.equal(optional.min_select, 0);
  assert.equal(optional.required, false);
  assert.equal(optional.max_select, 20);
  assert.equal(optional.choices[0].price, 10);
  assert.equal(normalizeFoodMenuOptionGroups([group({ min_select: 2 })])[0].required, true);
});

test("menu save rejects impossible minimums, duplicate IDs and invalid option prices", () => {
  assert.throws(() => normalizeFoodMenuOptionGroups([group({ min_select: 4 })]));
  assert.throws(() => normalizeFoodMenuOptionGroups([group({ min_select: 2, max_select: 1 })]));
  assert.throws(() => normalizeFoodMenuOptionGroups([group({ min_select: 1.5 })]));
  assert.throws(() => normalizeFoodMenuOptionGroups([group(), group()]));
  assert.throws(() => normalizeFoodMenuOptionGroups([group({ choices: [{ id: "egg", name: "egg", price: 0 }, { id: "egg", name: "egg2", price: 0 }] })]));
  for (const price of [-1, "invalid", Number.POSITIVE_INFINITY]) {
    assert.throws(() => normalizeFoodMenuOptionGroups([group({ choices: [{ id: "egg", name: "egg", price }] })]));
  }
});
