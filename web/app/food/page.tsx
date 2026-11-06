import { WynosFoodDeveloperApp } from "@/components/food/wynos-food-developer-app";

// Production resilience hotfix (2026-11-06):
// Keep /food server rendering independent from Supabase. The Food layout already
// provides the generic ZOKY metadata, while store data is loaded by the client.
// This prevents transient upstream socket/TLS failures from turning an optional
// link-preview lookup into a Vercel runtime error on the customer entry route.
export default function FoodPage() {
  return <WynosFoodDeveloperApp />;
}
