import type { Metadata } from "next";

import { LineEntry } from "@/components/line/line-entry";

import "./line.css";

export const metadata: Metadata = {
  title: "รับแจ้งเตือนทาง LINE — ZOKY",
  robots: { index: false, follow: false },
};

export default function LinePage() {
  return <LineEntry />;
}
