import type { CartLine, MenuItem, SelectedOption } from "./model";

export function lineKey(itemId: string, selections: SelectedOption[]): string {
  const optionKey = selections
    .map((o) => o.groupId + ":" + o.choiceId)
    .sort()
    .join("|");
  return itemId + "/" + optionKey;
}

export function unitPrice(basePrice: number, options: SelectedOption[]): number {
  return basePrice + options.reduce((sum, item) => sum + item.price, 0);
}

export function subtotal(lines: CartLine[]): number {
  return lines.reduce((sum, line) => sum + unitPrice(line.basePrice, line.options) * line.quantity, 0);
}

export function itemOptionError(item: MenuItem, selections: SelectedOption[]): string | null {
  for (const group of item.options) {
    const count = selections.filter((choice) => choice.groupId === group.id).length;
    if (group.required && count === 0) return "กรุณาเลือก " + group.name;
    if (count > group.maxSelect) return "เลือก " + group.name + " ได้สูงสุด " + group.maxSelect + " รายการ";
    if (selections.some((choice) =>
      choice.groupId === group.id &&
      !group.choices.some((allowed) => allowed.id === choice.choiceId)
    )) return "ตัวเลือกอาหารไม่ถูกต้อง";
  }
  if (selections.some((choice) => !item.options.some((group) => group.id === choice.groupId))) {
    return "ตัวเลือกอาหารไม่ถูกต้อง";
  }
  return null;
}

export function addLine(lines: CartLine[], next: CartLine): CartLine[] {
  const existing = lines.find((line) => line.key === next.key);
  if (!existing) return [...lines, next];
  return lines.map((line) => line.key === next.key
    ? { ...line, quantity: Math.min(99, line.quantity + next.quantity) }
    : line
  );
}
