import { createClient } from "@/lib/supabase/server";
export type FoodReviewModerationRow = {
 id:string;store_id:string;store_name:string;rating:number;
 review_text:string|null;tags:string[];reviewer_label:string;
 merchant_reply:string|null;is_hidden:boolean;created_at:string;updated_at:string;
};
export async function fetchFoodReviewModerationRows():Promise<FoodReviewModerationRow[]> {
 const client=await createClient();
 const {data,error}=await client.rpc("admin_food_review_moderation_feed",{p_limit:200});
 if(error)throw error;
 return Array.isArray(data)?data as FoodReviewModerationRow[]:[];
}
