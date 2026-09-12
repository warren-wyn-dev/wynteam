from pathlib import Path


def replace(path, old, new, count=1):
    p = Path(path)
    text = p.read_text()
    found = text.count(old)
    if found < count:
        raise SystemExit(
            f"{path}: expected at least {count} occurrence(s), found {found}: {old[:80]!r}"
        )
    p.write_text(text.replace(old, new, count))


for path in [
    "app/lib/core/typography/browser_system_text_stub.dart",
    "app/lib/core/typography/browser_system_text_web.dart",
]:
    replace(
        path,
        "    this.maxLines,\n    this.overflow,\n    this.textAlign = TextAlign.start,",
        "    this.maxLines,\n    this.softWrap,\n    this.overflow,\n    this.textAlign = TextAlign.start,",
        count=2,
    )
    replace(
        path,
        "  final int? maxLines;\n  final TextOverflow? overflow;",
        "  final int? maxLines;\n  final bool? softWrap;\n  final TextOverflow? overflow;",
        count=2,
    )

# Native implementation forwards Text's existing softWrap contract.
replace(
    "app/lib/core/typography/browser_system_text_stub.dart",
    "      maxLines: maxLines,\n      overflow: overflow,",
    "      maxLines: maxLines,\n      softWrap: softWrap,\n      overflow: overflow,",
)
replace(
    "app/lib/core/typography/browser_system_text_stub.dart",
    "      maxLines: widget.maxLines,\n      overflow: widget.overflow ?? TextOverflow.clip,",
    "      maxLines: widget.maxLines,\n      softWrap: widget.softWrap,\n      overflow: widget.overflow ?? TextOverflow.clip,",
)

# Web wrapper passes softWrap through and maps it to CSS white-space.
replace(
    "app/lib/core/typography/browser_system_text_web.dart",
    "      maxLines: maxLines,\n      overflow: overflow,",
    "      maxLines: maxLines,\n      softWrap: softWrap,\n      overflow: overflow,",
)
replace(
    "app/lib/core/typography/browser_system_text_web.dart",
    "        final height = math.max(_measuredHeight ?? estimatedHeight, 1);",
    "        final height = math.max(_measuredHeight ?? estimatedHeight, 1.0);",
)
replace(
    "app/lib/core/typography/browser_system_text_web.dart",
    "      ..whiteSpace = widget.maxLines == 1 ? 'nowrap' : 'pre-wrap'",
    "      ..whiteSpace = widget.softWrap == false || widget.maxLines == 1\n          ? 'nowrap'\n          : 'pre-wrap'",
)
replace(
    "app/lib/core/typography/browser_system_text_web.dart",
    "    final value = color.value;",
    "    final value = color.toARGB32();",
)
