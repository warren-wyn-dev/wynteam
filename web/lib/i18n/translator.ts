import { EN_EXACT, EN_PATTERNS } from "@/lib/i18n/en";
import type { AppLanguage } from "@/lib/i18n/language";

/**
 * WYN-189: shows the Thai-authored pages in English.
 *
 * Every text node and translatable attribute whose whole (trimmed) Thai text
 * is a known UI string is swapped for its English form; the Thai original is
 * remembered per node, so switching back to Thai restores it exactly. A
 * MutationObserver handles everything React renders or updates later.
 *
 * Only exact UI strings (and the templates in EN_PATTERNS) change, so
 * posts, names and messages written by people are left as they are. A
 * subtree can opt out with `data-i18n-skip`.
 */

const THAI = /[฀-๿]/;
const ATTRIBUTES = ["placeholder", "aria-label", "title", "alt"] as const;
const SKIP_SELECTOR = "[data-i18n-skip],script,style,noscript,[contenteditable='true']";

const escapeRegExp = (value: string) => value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

/** Each template becomes a regex; `order` maps capture groups to {n} (the Thai may put {1} first). */
const compiledPatterns = EN_PATTERNS.map(([thai, english]) => ({
  regex: new RegExp(`^${thai.split(/\{\d+\}/).map(escapeRegExp).join("(.+?)")}$`, "s"),
  order: [...thai.matchAll(/\{(\d+)\}/g)].map((match) => Number(match[1])),
  english,
}));

const THAI_MONTHS_SHORT = ["ม.ค.", "ก.พ.", "มี.ค.", "เม.ย.", "พ.ค.", "มิ.ย.", "ก.ค.", "ส.ค.", "ก.ย.", "ต.ค.", "พ.ย.", "ธ.ค."];
const THAI_MONTHS_LONG = ["มกราคม", "กุมภาพันธ์", "มีนาคม", "เมษายน", "พฤษภาคม", "มิถุนายน", "กรกฎาคม", "สิงหาคม", "กันยายน", "ตุลาคม", "พฤศจิกายน", "ธันวาคม"];
const EN_MONTHS_SHORT = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const EN_MONTHS_LONG = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
const monthAlternatives = [...THAI_MONTHS_LONG, ...THAI_MONTHS_SHORT].map(escapeRegExp).join("|");
/** "26 ก.ย.", "26 กันยายน 2026", "26 ก.ย. 2569" (Intl th-TH output). */
const THAI_DATE = new RegExp(`^(\\d{1,2}) (${monthAlternatives})(?: (\\d{4}))?$`);

/** `toLocaleString("th-TH")`: "27/9/2569 12:34:00". Buddhist-era years only, so other numeric dates are never touched. */
const THAI_NUMERIC_DATETIME = /^(\d{1,2})\/(\d{1,2})\/(2[5-9]\d{2})(?: (\d{1,2}:\d{2}(?::\d{2})?))?$/;

function translateDate(text: string): string | null {
  const numeric = THAI_NUMERIC_DATETIME.exec(text);
  if (numeric) {
    const year = Number(numeric[3]) - 543;
    return `${numeric[2]}/${numeric[1]}/${year}${numeric[4] ? `, ${numeric[4]}` : ""}`;
  }
  const match = THAI_DATE.exec(text);
  if (!match) return null;
  const longIndex = THAI_MONTHS_LONG.indexOf(match[2]);
  const month = longIndex >= 0 ? EN_MONTHS_LONG[longIndex] : EN_MONTHS_SHORT[THAI_MONTHS_SHORT.indexOf(match[2])];
  let year = match[3] ? Number(match[3]) : null;
  if (year && year > 2400) year -= 543; // Buddhist era
  return year ? `${month} ${match[1]}, ${year}` : `${month} ${match[1]}`;
}

/**
 * Fragments that follow an inserted value in the same element ("1,234" +
 * " สมาชิก") read in lower case in English.
 */
const EN_AFTER_VALUE: Record<string, string> = {
  "สมาชิก": "members",
  "โพสต์": "posts",
  "กำลังติดตาม": "following",
  "ผู้ติดตาม": "followers",
  "คน": "people",
  "ตัวอักษร": "characters",
  "โพสต์ · กำลังนิยมใน ไทย": "posts · Trending in Thailand",
};

const cache = new Map<string, string | null>();

/** English for one piece of Thai UI text, or null when it is not a known UI string. */
export function translateToEnglish(text: string): string | null {
  if (!THAI.test(text) && !THAI_NUMERIC_DATETIME.test(text.trim())) return null;
  const leading = text.match(/^\s*/)?.[0] ?? "";
  const trailing = text.match(/\s*$/)?.[0] ?? "";
  const core = text.trim();
  const key = leading ? `\u0001${core}` : core;
  let english = cache.get(key);
  if (english === undefined) {
    english = (leading ? EN_AFTER_VALUE[core] : undefined) ?? EN_EXACT[core] ?? translatePattern(core) ?? translateDate(core) ?? null;
    cache.set(key, english);
  }
  return english === null ? null : `${leading}${english}${trailing}`;
}

function translatePattern(text: string): string | null {
  for (const pattern of compiledPatterns) {
    const match = pattern.regex.exec(text);
    if (!match) continue;
    const values: string[] = [];
    pattern.order.forEach((slot, index) => {
      const value = match[index + 1];
      values[slot] = translateToEnglish(value) ?? value;
    });
    return pattern.english.replace(/\{(\d+)\}/g, (_, slot: string) => values[Number(slot)] ?? "");
  }
  return null;
}

type TextRecord = { thai: string; shown: string };

const textRecords = new WeakMap<Text, TextRecord>();
const attributeRecords = new WeakMap<Element, Map<string, TextRecord>>();
let observer: MutationObserver | null = null;
let active: AppLanguage = "th";
let originalTitle: TextRecord | null = null;
let restoreDialogs: (() => void) | null = null;

function skipped(node: Node): boolean {
  const element = node.nodeType === Node.ELEMENT_NODE ? (node as Element) : node.parentElement;
  return Boolean(element?.closest(SKIP_SELECTOR));
}

function applyText(node: Text) {
  // A textarea's text is what the person typed; its placeholder is still translated.
  if (node.parentElement?.tagName === "TEXTAREA") return;
  const current = node.data;
  const record = textRecords.get(node);
  // React (or anyone) wrote new text since we last translated: that is the new Thai original.
  const thai = record && record.shown === current ? record.thai : current;
  const shown = active === "en" ? (translateToEnglish(thai) ?? thai) : thai;
  if (shown !== thai || record) textRecords.set(node, { thai, shown });
  if (current !== shown) node.data = shown;
}

function applyAttribute(element: Element, name: string) {
  const current = element.getAttribute(name);
  let records = attributeRecords.get(element);
  const record = records?.get(name);
  if (current === null) {
    records?.delete(name);
    return;
  }
  const thai = record && record.shown === current ? record.thai : current;
  const shown = active === "en" ? (translateToEnglish(thai) ?? thai) : thai;
  if (shown !== thai || record) {
    if (!records) attributeRecords.set(element, (records = new Map()));
    records.set(name, { thai, shown });
  }
  if (current !== shown) element.setAttribute(name, shown);
}

/**
 * React attaches its fiber to every DOM node it renders or hydrates. A node
 * without one is server HTML React has not hydrated yet (a streamed Suspense
 * boundary): changing its text now would break hydration, so it waits.
 */
let fiberKey: string | null = null;
function hydrated(element: Element): boolean {
  if (fiberKey) return fiberKey in element;
  const key = Object.keys(element).find((name) => name.startsWith("__reactFiber$"));
  if (key) fiberKey = key;
  return Boolean(key);
}

const HYDRATION_WAIT_MS = 10_000;
const waiting = new Set<Element>();
let waitTimer: ReturnType<typeof setInterval> | null = null;
let waitDeadline = 0;

function waitForHydration(element: Element) {
  waiting.add(element);
  if (waitTimer) return;
  waitDeadline = Date.now() + HYDRATION_WAIT_MS;
  waitTimer = setInterval(() => {
    const force = Date.now() > waitDeadline;
    for (const element of [...waiting]) {
      if (!element.isConnected) waiting.delete(element);
      else if (force || hydrated(element)) {
        waiting.delete(element);
        applyTree(element, true);
      }
    }
    if (!waiting.size && waitTimer) {
      clearInterval(waitTimer);
      waitTimer = null;
    }
  }, 150);
}

function applyTree(root: Node, force = false) {
  if (root.nodeType === Node.TEXT_NODE) {
    const parent = root.parentElement;
    if (parent && !force && !hydrated(parent)) waitForHydration(parent);
    else if (!skipped(root)) applyText(root as Text);
    return;
  }
  if (root.nodeType !== Node.ELEMENT_NODE && root.nodeType !== Node.DOCUMENT_FRAGMENT_NODE) return;
  if (root.nodeType === Node.ELEMENT_NODE && skipped(root)) return;
  const walker = document.createTreeWalker(root, NodeFilter.SHOW_ELEMENT | NodeFilter.SHOW_TEXT, {
    acceptNode(node) {
      if (node.nodeType !== Node.ELEMENT_NODE) return NodeFilter.FILTER_ACCEPT;
      const element = node as Element;
      if (element.matches(SKIP_SELECTOR)) return NodeFilter.FILTER_REJECT;
      if (!force && !hydrated(element)) {
        waitForHydration(element);
        return NodeFilter.FILTER_REJECT;
      }
      return NodeFilter.FILTER_ACCEPT;
    },
  });
  // The walker never tests `root` itself.
  if (root.nodeType === Node.ELEMENT_NODE && !force && !hydrated(root as Element)) {
    waitForHydration(root as Element);
    return;
  }
  for (let node: Node | null = walker.currentNode; node; node = walker.nextNode()) {
    if (node.nodeType === Node.TEXT_NODE) applyText(node as Text);
    else if (node.nodeType === Node.ELEMENT_NODE) for (const name of ATTRIBUTES) if ((node as Element).hasAttribute(name)) applyAttribute(node as Element, name);
  }
}

function applyTitle() {
  const current = document.title;
  const thai = originalTitle && originalTitle.shown === current ? originalTitle.thai : current;
  const shown = active === "en" ? (translateToEnglish(thai) ?? thai) : thai;
  originalTitle = { thai, shown };
  if (current !== shown) document.title = shown;
}

/** Confirm/alert texts are Thai strings too. */
function patchDialogs() {
  if (restoreDialogs) return;
  const { alert, confirm, prompt } = window;
  const english = (message?: unknown) => (typeof message === "string" ? (translateToEnglish(message) ?? message) : message);
  window.alert = (message?: unknown) => alert.call(window, active === "en" ? english(message) : message);
  window.confirm = (message?: string) => confirm.call(window, active === "en" ? (english(message) as string) : message);
  window.prompt = (message?: string, value?: string) => prompt.call(window, active === "en" ? (english(message) as string) : message, value);
  restoreDialogs = () => {
    window.alert = alert;
    window.confirm = confirm;
    window.prompt = prompt;
  };
}

function onMutations(mutations: MutationRecord[]) {
  for (const mutation of mutations) {
    if (mutation.type === "characterData") {
      if (!skipped(mutation.target)) applyText(mutation.target as Text);
    } else if (mutation.type === "attributes" && mutation.attributeName) {
      if (!skipped(mutation.target)) applyAttribute(mutation.target as Element, mutation.attributeName);
    } else {
      mutation.addedNodes.forEach((node) => applyTree(node));
      if (mutation.target.nodeName === "TITLE") applyTitle();
    }
  }
}

/**
 * Show the page in `language`. English starts watching the page; Thai puts
 * every remembered original back and stops watching.
 */
export function applyLanguage(language: AppLanguage) {
  if (typeof document === "undefined") return;
  active = language;
  const root = document.documentElement;
  root.lang = language;
  if (language === "en" && !observer) {
    observer = new MutationObserver(onMutations);
    observer.observe(document.body, { subtree: true, childList: true, characterData: true, attributes: true, attributeFilter: [...ATTRIBUTES] });
    const title = document.querySelector("head > title");
    if (title) observer.observe(title, { childList: true, characterData: true, subtree: true });
    patchDialogs();
  }
  applyTree(document.body);
  applyTitle();
  if (observer) observer.takeRecords();
  if (language === "th") {
    observer?.disconnect();
    observer = null;
    restoreDialogs?.();
    restoreDialogs = null;
  }
  root.removeAttribute("data-i18n-pending");
}
