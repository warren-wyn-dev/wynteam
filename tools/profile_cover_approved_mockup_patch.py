from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, found {count}")
    return text.replace(old, new, 1)


# 1) Increase the approved Profile cover height by ~12% (108 -> 121).
metrics_path = ROOT / "app/lib/core/design/wynos_founder_metrics.dart"
metrics = metrics_path.read_text(encoding="utf-8")
metrics = replace_once(
    metrics,
    "  static const double profileCoverExpandedHeight = 108;",
    "  static const double profileCoverExpandedHeight = 121;",
    "profile cover height",
)
metrics_path.write_text(metrics, encoding="utf-8")


# 2) Keep the no-back-button layout, but give the Profile title the approved
# 16px left inset so it never clips against the viewport edge.
view_path = ROOT / "app/lib/features/profile/presentation/view_profile_screen.dart"
view = view_path.read_text(encoding="utf-8")
old = """            child: Row(\n              children: [\n                const Text(\n                  'โปรไฟล์',\n"""
new = """            child: Row(\n              children: [\n                const SizedBox(width: 16),\n                const Text(\n                  'โปรไฟล์',\n"""
view = replace_once(view, old, new, "profile title left inset")
view_path.write_text(view, encoding="utf-8")

print("Applied approved Profile cover mockup polish")
