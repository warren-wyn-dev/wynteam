import type { SupabaseClient } from "@supabase/supabase-js";
export type FoodFeaturedPlacement = {store_id:string;priority:number};
export async function fetchFoodFeaturedStores(client:SupabaseClient):Promise<FoodFeaturedPlacement[]>{
 const {data,error}=await client.rpc("food_active_featured_stores");
 return error || !Array.isArray(data) ? [] : data as FoodFeaturedPlacement[];
}
