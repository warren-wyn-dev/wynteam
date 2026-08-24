/**
 * Shared placeholder for the 5 sections that don't have real content
 * yet (Design spec's Screen 2: "Placeholder ทั้ง 5 หน้าต้องใช้ copy
 * เดียวกันทุกจุด (แค่เปลี่ยนชื่อ feature/เลข task)"). Dashboard uses this
 * too until WYN-050 lands.
 */
export function PlaceholderPage({ feature, task }: { feature: string; task: string }) {
  return (
    <div className="flex flex-1 items-center justify-center p-6">
      <p className="text-center text-muted-foreground">
        {feature} พร้อมใช้งาน — ฟีเจอร์เต็มรูปแบบจะเพิ่มใน {task}
      </p>
    </div>
  );
}
