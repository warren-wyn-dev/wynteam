import { Badge } from "@/components/ui/badge";
import type { WynosAccountSnapshot } from "@/lib/admin-account-services";

const SERVICES = [
  { key: "social_profile", label: "WYNOS Social", found: "มีโปรไฟล์" },
  { key: "food_activity", label: "WYNOS Food", found: "พบกิจกรรม" },
  { key: "merchant_record", label: "WYNOS Merchant", found: "มีข้อมูล Merchant" },
  { key: "maps_activity", label: "WYNOS Maps", found: "พบกิจกรรม" },
] as const;

/** No action buttons: service evidence is not service enrollment or approval. */
export function AccountServiceStatus({ snapshot }: { snapshot: WynosAccountSnapshot }) {
  return (
    <section aria-labelledby="wynos-account-heading" className="flex flex-col gap-3 rounded-xl border p-4">
      <div className="flex flex-col gap-1">
        <h3 id="wynos-account-heading" className="font-semibold">WYNOS Account — บัญชีกลาง</h3>
        <p className="break-all text-xs text-muted-foreground">Account ID: {snapshot.account_id}</p>
      </div>
      <div className="grid grid-cols-1 gap-2 sm:grid-cols-2">
        {SERVICES.map((service) => (
          <div key={service.key} className="flex items-center justify-between gap-2 rounded-lg border p-3">
            <span className="text-sm font-medium">{service.label}</span>
            {snapshot.signals[service.key] ? (
              <Badge variant="secondary">{service.found}</Badge>
            ) : (
              <Badge variant="outline">ยังไม่พบข้อมูล</Badge>
            )}
          </div>
        ))}
      </div>
      <p className="text-xs leading-relaxed text-muted-foreground">
        แสดงหลักฐานที่มีอยู่ในฐานข้อมูล ไม่ใช่สถานะการเข้าสู่ระบบหรือการเริ่มใช้บริการ
        การไม่พบข้อมูลไม่ได้แปลว่าผู้ใช้ไม่เคยเข้าใช้บริการนั้น
      </p>
    </section>
  );
}
