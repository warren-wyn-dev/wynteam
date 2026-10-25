import { createClient } from "@/lib/supabase/server";
export type AdminFeaturedStore = {
 store_id:string;store_name:string;priority:number;active:boolean;
 starts_at:string;ends_at:string|null;version:number;
};
export type AdminStoreOption = {id:string;name:string};
export async function getFoodFeaturedAdminData():Promise<{rows:AdminFeaturedStore[];stores:AdminStoreOption[]}> {
 const c=await createClient();
 const [placements,stores]=await Promise.all([
   c.rpc("admin_food_featured_stores"),
   c.rpc("admin_food_stores",{p_query:null})
 ]);
 if(placements.error)throw placements.error;
 if(stores.error)throw stores.error;
 return {
   rows:Array.isArray(placements.data)?placements.data as AdminFeaturedStore[]:[],
   stores:Array.isArray(stores.data)?stores.data.map((r:{id:string;name:string})=>({id:r.id,name:r.name})):[],
 };
}
