import Link from "next/link";

export function HomeNavigationBridge() {
  return (
    <div className="home-nav-bridge" aria-label="ลิงก์ Web รุ่นใหม่">
      <Link className="bridge-top-search" href="/search" aria-label="ค้นหา" />
      <Link className="bridge-top-menu" href="/settings" aria-label="ตั้งค่า" />
      <Link className="bridge-bottom-search" href="/search" aria-label="ค้นหา" />
      <Link className="bridge-bottom-notifications" href="/notifications" aria-label="การแจ้งเตือน" />
      <Link className="bridge-bottom-profile" href="/profile/me" aria-label="โปรไฟล์" />
    </div>
  );
}
