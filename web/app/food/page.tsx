import { WynosFoodDeveloperApp } from "@/components/food/wynos-food-developer-app";

// Keep the Food entry route independent from Supabase during server rendering.
// Store-specific preview data is optional and must not turn transient upstream
// network failures into a runtime error for customers opening the app.
export default function FoodPage() {
  return <WynosFoodDeveloperApp />;
}
