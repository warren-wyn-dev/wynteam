import { createClient } from "@/lib/supabase/server";
import { requireAdminRole } from "@/lib/auth";
import { fetchAdminFoodOrders } from "@/lib/admin-food";
import { toSafeIlikePattern } from "@/lib/admin-search-query.mjs";

export type AdminSearchCategory = "users" | "stores" | "orders";

export type AdminSearchItem = {
  id: string;
  label: string;
  sublabel: string;
  href: string;
};

export type AdminSearchSection = {
  id: AdminSearchCategory;
  label: string;
  status: "ready" | "unavailable";
  results: AdminSearchItem[];
};

const PER_CATEGORY_LIMIT = 6;

async function searchProfiles(term: string): Promise<AdminSearchItem[]> {
  const supabase = await createClient();
  const pattern = toSafeIlikePattern(term);
  // Two independently parameterized queries. Never interpolate user input
  // into a PostgREST .or() expression.
  const [names, displays] = await Promise.all([
    supabase.from("profiles").select("id, username, display_name")
      .ilike("username", pattern).order("username").limit(PER_CATEGORY_LIMIT),
    supabase.from("profiles").select("id, username, display_name")
      .ilike("display_name", pattern).order("username").limit(PER_CATEGORY_LIMIT),
  ]);
  if (names.error || displays.error) throw new Error("Profile lookup unavailable");

  const uniq = new Map<string, AdminSearchItem>();
  for (const row of [...(names.data ?? []), ...(displays.data ?? [])]) {
    if (typeof row.id !== "string" || typeof row.username !== "string") continue;
    uniq.set(row.id, {
      id: row.id,
      label: row.display_name || row.username,
      sublabel: "@" + row.username,
      href: "/users/" + encodeURIComponent(row.id),
    });
    if (uniq.size >= PER_CATEGORY_LIMIT) break;
  }
  return [...uniq.values()];
}

async function searchStores(term: string): Promise<AdminSearchItem[]> {
  const supabase = await createClient();
  // Existing role-gated Admin RPC. RPC response is projected onto safe
  // fields server-side: no phones, staff, addresses or sales reach the UI.
  const { data, error } = await supabase.rpc("admin_food_stores", { p_query: term })
    .limit(PER_CATEGORY_LIMIT);
  if (error) throw new Error("Store lookup unavailable");
  const rows = (data ?? []) as Array<{ id: string; name: string; slug: string }>;
  return rows.filter((row) => row.id && row.name).slice(0, PER_CATEGORY_LIMIT).map((row) => ({
    id: row.id,
    label: row.name,
    sublabel: "ร้านอาหาร · WYNOS Food",
    href: "/food/stores/" + encodeURIComponent(row.id),
  }));
}

async function searchOrderNumbers(term: string): Promise<AdminSearchItem[]> {
  // Require a plausible order reference. Never search for phone, recipient
  // name or other sensitive customer information by arbitrary substring.
  if (!/^[A-Za-z0-9-]{4,48}$/.test(term)) return [];
  const rows = await fetchAdminFoodOrders({ query: term, limit: PER_CATEGORY_LIMIT });
  return rows.filter((row) => row.order_number.toLowerCase().includes(term.toLowerCase()))
    .slice(0, PER_CATEGORY_LIMIT).map((row) => ({
      id: row.id,
      label: row.order_number,
      sublabel: "ออเดอร์ · WYNOS Food",
      href: "/food/orders/" + encodeURIComponent(row.id),
    }));
}

async function safeSection(
  id: AdminSearchCategory,
  label: string,
  run: () => Promise<AdminSearchItem[]>,
): Promise<AdminSearchSection> {
  try {
    return { id, label, status: "ready", results: await run() };
  } catch {
    // Never leak raw backend errors or represent an outage as zero results.
    return { id, label, status: "unavailable", results: [] };
  }
}

/** Called from a Server Component only; rechecks caller's real session. */
export async function fetchAdminGlobalSearch(term: string): Promise<AdminSearchSection[]> {
  const { role } = await requireAdminRole();
  const users = safeSection("users", "ผู้ใช้ Social", () => searchProfiles(term));

  if (role === "moderator") {
    // No privileged store/order queries, including invisible background
    // requests. An authorized Moderator sees only the public-profile source.
    return [await users];
  }
  const [userResult, stores, orders] = await Promise.all([
    users,
    safeSection("stores", "ร้านอาหาร", () => searchStores(term)),
    safeSection("orders", "หมายเลขออเดอร์", () => searchOrderNumbers(term)),
  ]);
  return [userResult, stores, orders];
}
