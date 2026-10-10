/** WYN-219: shown instead of a page the signed-in account has no permission for. */
export function NoAccess({ what }: { what: string }) {
  return (
    <div className="p-6">
      <p className="rounded-xl border border-dashed p-10 text-center text-sm text-muted-foreground">
        คุณยังไม่มีสิทธิ์{what} ติดต่อ super admin เพื่อขอสิทธิ์
      </p>
    </div>
  );
}
