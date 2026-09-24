import { redirect } from "next/navigation";

import { FoodDemoApp } from "@/components/food/food-demo-app";
import "../../food/food.css";

/** Browser QA only: fake Food records, no auth/backend calls. Production
 * never exposes a bypass to the developer-gated /food experience. */
export default function FoodFixturePage() {
  if (process.env.NODE_ENV === "production") redirect("/");
  return <FoodDemoApp />;
}
