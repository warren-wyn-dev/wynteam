export type FoodBusinessDay = {
  enabled: boolean;
  open: string;
  close: string;
};

export type FoodBusinessSchedule = {
  weekly: Record<string, FoodBusinessDay>;
};

export type FoodAvailabilityStore = {
  is_open: boolean;
  business_schedule?: FoodBusinessSchedule | Record<string, unknown> | null;
  special_closed_dates?: string[] | null;
  temporary_closed_until?: string | null;
  temporary_closed_reason?: string | null;
  prep_time_min_minutes?: number | null;
  prep_time_max_minutes?: number | null;
};

export type FoodAvailabilityMenuItem = {
  is_available: boolean;
  sold_out_until?: string | null;
};

export const FOOD_DAY_KEYS = ["mon","tue","wed","thu","fri","sat","sun"] as const;

export function defaultFoodBusinessSchedule(): FoodBusinessSchedule {
  return {
    weekly: Object.fromEntries(
      FOOD_DAY_KEYS.map((key) => [key, { enabled: true, open: "09:00", close: "21:00" }]),
    ),
  };
}

function bangkokParts(at: Date) {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Bangkok",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
    weekday: "short",
  }).formatToParts(at);
  const value = (type: Intl.DateTimeFormatPartTypes) => parts.find((p) => p.type === type)?.value ?? "";
  const weekdayMap: Record<string, number> = { Mon: 0, Tue: 1, Wed: 2, Thu: 3, Fri: 4, Sat: 5, Sun: 6 };
  return {
    date: `${value("year")}-${value("month")}-${value("day")}`,
    minutes: Number(value("hour")) * 60 + Number(value("minute")),
    weekday: weekdayMap[value("weekday")] ?? 0,
    year: Number(value("year")),
    month: Number(value("month")),
    day: Number(value("day")),
  };
}

function hhmm(value: string | undefined) {
  const match = /^(\d{1,2}):(\d{2})$/.exec(value ?? "");
  if (!match) return null;
  const h = Number(match[1]);
  const m = Number(match[2]);
  if (h < 0 || h > 23 || m < 0 || m > 59) return null;
  return h * 60 + m;
}

function normalizedSchedule(value: FoodAvailabilityStore["business_schedule"]): FoodBusinessSchedule | null {
  if (!value || typeof value !== "object" || !("weekly" in value)) return null;
  const weekly = (value as FoodBusinessSchedule).weekly;
  if (!weekly || typeof weekly !== "object") return null;
  return { weekly };
}

export function foodStoreIsEffectivelyOpen(store: FoodAvailabilityStore, at = new Date()) {
  if (!store.is_open) return false;
  if (store.temporary_closed_until) {
    const until = Date.parse(store.temporary_closed_until);
    if (Number.isFinite(until) && until > at.getTime()) return false;
  }
  const schedule = normalizedSchedule(store.business_schedule);
  if (!schedule) return true;

  const bkk = bangkokParts(at);
  if (store.special_closed_dates?.includes(bkk.date)) return false;

  const today = schedule.weekly[FOOD_DAY_KEYS[bkk.weekday]];
  if (today?.enabled) {
    const open = hhmm(today.open);
    const close = hhmm(today.close);
    if (open != null && close != null) {
      if (open === close) return true;
      if (close > open && bkk.minutes >= open && bkk.minutes < close) return true;
      if (close < open && bkk.minutes >= open) return true;
    }
  }

  const previousIndex = (bkk.weekday + 6) % 7;
  const previous = schedule.weekly[FOOD_DAY_KEYS[previousIndex]];
  if (previous?.enabled) {
    const open = hhmm(previous.open);
    const close = hhmm(previous.close);
    if (open != null && close != null && close < open && bkk.minutes < close) return true;
  }
  return false;
}

export function foodStoreStatusText(store: FoodAvailabilityStore, at = new Date()) {
  if (!store.is_open) return "ปิดรับออเดอร์";
  if (store.temporary_closed_until && Date.parse(store.temporary_closed_until) > at.getTime()) {
    return store.temporary_closed_reason?.trim() || "ปิดชั่วคราว";
  }
  if (!foodStoreIsEffectivelyOpen(store, at)) return "ปิดตามเวลาร้าน";
  return "เปิดรับออเดอร์";
}

export function foodMenuIsEffectivelyAvailable(item: FoodAvailabilityMenuItem, at = new Date()) {
  if (!item.is_available) return false;
  if (!item.sold_out_until) return true;
  const until = Date.parse(item.sold_out_until);
  return !Number.isFinite(until) || until <= at.getTime();
}

export function foodSoldOutUntilTomorrowBangkok(at = new Date()) {
  const bkk = bangkokParts(at);
  return new Date(Date.UTC(bkk.year, bkk.month - 1, bkk.day + 1, -7, 0, 0)).toISOString();
}

export function foodEstimateDeliveryRange(
  store: Pick<FoodAvailabilityStore, "prep_time_min_minutes" | "prep_time_max_minutes">,
  distanceKm: number | null | undefined,
) {
  const prepMin = Math.max(1, Number(store.prep_time_min_minutes ?? 15));
  const prepMax = Math.max(prepMin, Number(store.prep_time_max_minutes ?? 30));
  const distance = Math.max(0, Number(distanceKm ?? 0));
  // City delivery planning assumption: ~22 km/h plus five minutes handoff.
  const travel = distance > 0 ? Math.ceil((distance / 22) * 60) + 5 : 0;
  return { min: prepMin + travel, max: prepMax + travel };
}
