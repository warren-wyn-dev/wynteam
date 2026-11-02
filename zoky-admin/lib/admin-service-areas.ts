import type { ServiceArea, ServiceAreaData } from "@/lib/admin-service-area-types";
import { createClient } from "@/lib/supabase/server";

export type { ServiceArea, ServiceAreaData } from "@/lib/admin-service-area-types";

/** admin_zoky_service_areas re-checks food view / super admin on the server. */
export async function getServiceAreas(): Promise<ServiceAreaData> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_zoky_service_areas");
  if (error) throw error;
  const value = (data ?? {}) as { can_edit?: unknown; areas?: unknown };
  return {
    canEdit: value.can_edit === true,
    areas: Array.isArray(value.areas) ? (value.areas as ServiceArea[]) : [],
  };
}
