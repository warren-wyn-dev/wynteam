export type FoodMenuOptionChoice = {
  id: string;
  name: string;
  price: number | string;
};

export type FoodMenuOptionGroup = {
  id: string;
  name: string;
  required: boolean;
  /** Older menus omit this field; required then means a minimum of one. */
  min_select?: number;
  max_select: number;
  choices: FoodMenuOptionChoice[];
};

export type FoodMenuOptionSelection = {
  group_id: string;
  group_name?: string;
  choice_id: string;
  choice_name?: string;
  price?: number | string;
};

export function foodOptionSelectionBounds(group: Pick<FoodMenuOptionGroup, "required" | "min_select" | "max_select">) {
  // Match the existing backend/client cap, including older menus saved above 20.
  const max = Math.max(1, Math.min(20, Math.floor(Number(group.max_select ?? 1))));
  const configuredMin = Number(group.min_select ?? (group.required ? 1 : 0));
  const min = Math.max(group.required ? 1 : 0, configuredMin);
  const valid = Number.isFinite(max) && Number.isInteger(configuredMin)
    && configuredMin >= 0 && configuredMin <= 20 && min <= max;
  return { min, max, valid };
}

export function foodOptionSelectionHint({ min, max }: { min: number; max: number }) {
  if (min === max) return `เลือก ${min} รายการ`;
  if (min > 0) return `เลือกอย่างน้อย ${min} รายการ สูงสุด ${max} รายการ`;
  return `เลือกได้สูงสุด ${max} รายการ`;
}

export function foodMenuSelectionsValid(
  groups: readonly FoodMenuOptionGroup[],
  selected: readonly Pick<FoodMenuOptionSelection, "group_id" | "choice_id">[],
) {
  const groupIds = new Set(groups.map((group) => group.id));
  if (groupIds.size !== groups.length) return false;
  const seen = new Set<string>();
  for (const option of selected) {
    const key = `${option.group_id}:${option.choice_id}`;
    if (seen.has(key)) return false;
    seen.add(key);
    const group = groups.find((row) => row.id === option.group_id);
    if (!group || !group.choices.some((choice) => choice.id === option.choice_id)) return false;
  }
  return groups.every((group) => {
    const { min, max, valid } = foodOptionSelectionBounds(group);
    const count = selected.filter((option) => option.group_id === group.id).length;
    return valid && count >= min && count <= max;
  });
}

export function normalizeFoodMenuOptionGroups(groups: readonly FoodMenuOptionGroup[]): FoodMenuOptionGroup[] {
  const normalized = groups.map((group) => ({
    ...group,
    id: String(group.id || "").trim(),
    name: String(group.name || "").trim(),
    choices: (group.choices ?? []).map((choice) => ({
      id: String(choice.id || "").trim(),
      name: String(choice.name || "").trim(),
      price: Number(choice.price ?? 0),
    })).filter((choice) => choice.name),
  })).filter((group) => group.name && group.choices.length);
  const groupIds = new Set<string>();
  return normalized.map((group) => {
    const { min, max, valid } = foodOptionSelectionBounds(group);
    if (!valid || min > group.choices.length) throw new Error("จำนวนตัวเลือกขั้นต่ำหรือสูงสุดไม่ถูกต้อง");
    if (!group.id || groupIds.has(group.id)) throw new Error("กลุ่มตัวเลือกไม่ถูกต้องหรือซ้ำกัน");
    groupIds.add(group.id);
    const choiceIds = new Set<string>();
    for (const choice of group.choices) {
      if (!choice.id || choiceIds.has(choice.id)) throw new Error("ตัวเลือกไม่ถูกต้องหรือซ้ำกัน");
      if (!Number.isFinite(choice.price) || choice.price < 0) throw new Error("ราคาตัวเลือกไม่ถูกต้อง");
      choiceIds.add(choice.id);
    }
    return { ...group, required: min > 0, min_select: min, max_select: max };
  });
}
