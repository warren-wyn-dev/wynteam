import { createClient } from "@/lib/supabase/server";

/**
 * GP v1 (supabase/migrations/20261011140000_merchant_gp_v1.sql). Rates are
 * integer basis points (2000 = 20.00%) and money is integer satang, so
 * nothing here does floating-point money maths.
 */

export type GpNext = { id: string; rate_bp: number; effective_from: string; effective_to: string | null } | null;

export type GpSettings = {
  can_edit: boolean;
  rule_version: string;
  default: { rate_bp: number; rate_id: string | null; next: GpNext };
  stores: Array<{
    store_id: string;
    store_name: string;
    is_published: boolean;
    suspended: boolean;
    rate_bp: number;
    source: "store" | "default" | "none";
    next: GpNext;
  }>;
  history: Array<{
    id: string;
    store_id: string | null;
    store_name: string | null;
    rate_bp: number;
    effective_from: string;
    effective_to: string | null;
    reason: string;
    created_by_username: string | null;
    created_at: string;
    cancelled_at: string | null;
    cancelled_by_username: string | null;
    cancel_reason: string | null;
  }>;
};

export async function fetchGpSettings(): Promise<GpSettings> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_gp_settings");
  if (error) throw error;
  return data as GpSettings;
}
