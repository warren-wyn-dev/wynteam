/** Bottom sheet used across the Club page (options, reports, announcements). */
export function BottomSheet({ children, label, onClose }: { children: React.ReactNode; label: string; onClose: () => void }) {
  return (
    <div className="route-modal-backdrop golden-club-sheet-backdrop" role="presentation" onClick={onClose}>
      <section className="golden-club-sheet" role="dialog" aria-modal="true" aria-label={label} onClick={(event) => event.stopPropagation()}>
        <div className="golden-club-sheet-grip" />
        {children}
      </section>
    </div>
  );
}
