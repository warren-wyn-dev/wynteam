import type { Metadata } from "next";

import { WynosFoodPreviewRoute } from "@/components/food/wynos-food-preview-route";

export const metadata: Metadata = {
  title: "WYNOS Food — ตัวอย่างสำหรับนักพัฒนา",
  robots: { index: false, follow: false },
};

export default function FoodPage() {
  return <WynosFoodPreviewRoute />;
}
