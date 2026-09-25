import type { Metadata } from "next";
import { PlusRoute } from "@/components/plus-route";
export const metadata: Metadata = { title: "WYNOS Plus" };
export default function Page() { return <PlusRoute />; }
