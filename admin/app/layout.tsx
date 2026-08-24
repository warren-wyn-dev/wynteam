import type { Metadata } from "next";
import "./globals.css";

/**
 * No next/font/google here deliberately -- Google Fonts fetch at build
 * time over the network, which this project's various build sandboxes
 * have not reliably had access to (see e.g. the Flutter app's own
 * build logs). System font stack via Tailwind's default `font-sans`
 * needs no network dependency and is standard for an internal tool.
 */
export const metadata: Metadata = {
  title: "WYN Admin",
  description: "WYN Admin -- ระบบหลังบ้านสำหรับผู้ดูแลระบบและผู้ตรวจสอบเนื้อหา",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="th" className="h-full antialiased">
      <body className="min-h-full flex flex-col font-sans">{children}</body>
    </html>
  );
}
