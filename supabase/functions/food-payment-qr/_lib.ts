export type PromptPayProxy = {
  tag: "01" | "02" | "03";
  value: string;
};

function tlv(tag: string, value: string) {
  return tag + String(value.length).padStart(2, "0") + value;
}

export function promptPayProxy(raw: string): PromptPayProxy {
  const digits = raw.replace(/\D/g, "");
  if (digits.length === 10 && digits.startsWith("0")) {
    return { tag: "01", value: "0066" + digits.slice(1) };
  }
  if (digits.length === 13) return { tag: "02", value: digits };
  if (digits.length === 15) return { tag: "03", value: digits };
  throw new Error("unsupported PromptPay ID");
}

export function crc16Ccitt(input: string) {
  let crc = 0xffff;
  for (const char of new TextEncoder().encode(input)) {
    crc ^= char << 8;
    for (let bit = 0; bit < 8; bit += 1) {
      crc = (crc & 0x8000) !== 0 ? ((crc << 1) ^ 0x1021) : (crc << 1);
      crc &= 0xffff;
    }
  }
  return crc.toString(16).toUpperCase().padStart(4, "0");
}

export function buildPromptPayPayload(rawPromptPayId: string, amount: number) {
  if (!Number.isFinite(amount) || amount <= 0 || amount > 999999999.99) {
    throw new Error("invalid PromptPay amount");
  }
  const proxy = promptPayProxy(rawPromptPayId);
  const merchantAccount = tlv("00", "A000000677010111") + tlv(proxy.tag, proxy.value);
  const body = [
    tlv("00", "01"),
    tlv("01", "12"),
    tlv("29", merchantAccount),
    tlv("53", "764"),
    tlv("54", amount.toFixed(2)),
    tlv("58", "TH"),
  ].join("");
  const withCrcTag = body + "6304";
  return withCrcTag + crc16Ccitt(withCrcTag);
}
