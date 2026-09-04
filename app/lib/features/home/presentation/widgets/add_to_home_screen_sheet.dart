import 'package:flutter/material.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../../../core/design/wyn_spacing.dart';
import '../../../../core/design/wyn_typography.dart';
import '../../../../core/web/home_screen_platform.dart';

/// WYN-107 (Add to Home Screen prompt), Screen 2 -- opens the full,
/// platform-specific step-by-step "how to add WYNOS to your home screen"
/// instructions as a modal bottom sheet. Mirrors `showAccountSwitcherSheet`
/// exactly (`isScrollControlled: true`, [WynColors.paper] background,
/// [WynSpacing.radiusLg] rounded top corners).
///
/// The single, shared entry point both `AddToHomeScreenBanner` (tapping
/// the banner body) and SettingsScreen's own entry-point row call --
/// neither duplicates this sheet's content, per the design doc's
/// Handoff §4/§5 ("ห้าม copy เนื้อหา sheet ซ้ำ").
///
/// [platformKind] is injectable (defaults to the real
/// [detectWebPlatformKind]) purely for tests; production callers that
/// already know which platform they detected (e.g. the banner, which
/// already ran the same check to decide whether to show itself at all)
/// pass their own resolved function through instead of re-detecting.
Future<void> showAddToHomeScreenSheet(
  BuildContext context, {
  WebPlatformKind Function() platformKind = detectWebPlatformKind,
}) {
  final kind = platformKind();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: WynColors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(WynSpacing.radiusLg)),
    ),
    builder: (_) => AddToHomeScreenSheet(platformKind: kind),
  );
}

/// One `_Step`'s icon + copy -- `**bold**` markers inside [text] are the
/// design doc's own verbatim markdown emphasis, rendered as real bold
/// spans by [_parseBoldMarkup] rather than left as literal asterisks.
class _Step {
  const _Step(this.icon, this.text);

  final IconData icon;

  /// Copied verbatim from the design doc -- do not reword/reorder (see
  /// this file's own Handoff note); `**...**` marks the bold segment(s).
  final String text;
}

// Design doc's Screen 2, "เนื้อหาขั้นตอน — iOS Safari" -- verbatim.
const _iosSteps = [
  _Step(Icons.ios_share,
      'แตะไอคอน **แชร์** (กล่องมีลูกศรชี้ขึ้น) ที่แถบด้านล่างของ Safari'),
  _Step(Icons.add_to_home_screen,
      'เลื่อนหาแล้วแตะ **เพิ่มไปยังหน้าจอโฮม** (Add to Home Screen)'),
  _Step(Icons.check_circle_outline, 'แตะ **เพิ่ม** ที่มุมขวาบน เป็นอันเสร็จ'),
];

// Design doc's Screen 2, "เนื้อหาขั้นตอน — Android Chrome" -- verbatim.
const _androidSteps = [
  _Step(Icons.more_vert, 'แตะไอคอนจุดสามจุด (⋮) มุมขวาบนของ Chrome'),
  _Step(Icons.install_mobile,
      'แตะ **ติดตั้งแอป** หรือ **เพิ่มไปยังหน้าจอหลัก** (ข้อความอาจต่างกันเล็กน้อยตามเวอร์ชัน Chrome)'),
  _Step(Icons.check_circle_outline,
      'แตะ **ติดตั้ง**/**เพิ่ม** เพื่อยืนยัน เป็นอันเสร็จ'),
];

class AddToHomeScreenSheet extends StatelessWidget {
  const AddToHomeScreenSheet({super.key, required this.platformKind});

  final WebPlatformKind platformKind;

  @override
  Widget build(BuildContext context) {
    // Callers only ever open this once isAddToHomeScreenEligible already
    // resolved to iosSafari/androidChrome (design doc: "sheet นี้จะไม่ถูก
    // เปิดเลยตั้งแต่ต้น" otherwise) -- anything other than iosSafari here
    // still degrades to the Android copy rather than crashing.
    final steps =
        platformKind == WebPlatformKind.iosSafari ? _iosSteps : _androidSteps;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: WynSpacing.space2),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: WynSpacing.space4),
                  decoration: BoxDecoration(
                    color: WynColors.hairline,
                    borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
                  ),
                ),
              ),
              Text(
                'เพิ่ม WYNOS ไว้ที่หน้าจอหลัก',
                style: WynTypography.screenTitle(fontSize: 18, color: WynColors.ink),
              ),
              const SizedBox(height: WynSpacing.space1),
              const Text(
                'เปิดใช้งานได้เร็วเหมือนแอปจริง ไม่ต้องเปิดเบราว์เซอร์ใหม่ทุกครั้ง',
                style: TextStyle(fontSize: 15, color: WynColors.graphite, height: 1.45),
              ),
              const SizedBox(height: WynSpacing.space4),
              for (var i = 0; i < steps.length; i++) ...[
                if (i > 0) const SizedBox(height: WynSpacing.space4),
                _StepRow(index: i + 1, step: steps[i]),
              ],
              const SizedBox(height: WynSpacing.space6),
              SizedBox(
                width: double.infinity,
                height: WynSpacing.touchTargetMin,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('เข้าใจแล้ว', style: TextStyle(color: WynColors.graphite)),
                ),
              ),
              const SizedBox(height: WynSpacing.space4),
            ],
          ),
        ),
      ),
    );
  }
}

/// One numbered step row -- circled index + icon + copy, per the design
/// doc's Screen 2 Components list. A single [Semantics] wraps the whole
/// row as one sentence ("ขั้นตอนที่ N: ...") rather than letting a screen
/// reader announce the number/icon/text as 3 separate elements, per that
/// same section's Accessibility note.
class _StepRow extends StatelessWidget {
  const _StepRow({required this.index, required this.step});

  final int index;
  final _Step step;

  @override
  Widget build(BuildContext context) {
    const baseStyle = TextStyle(fontSize: 15, color: WynColors.ink, height: 1.45);
    final boldStyle = baseStyle.copyWith(fontWeight: FontWeight.w700);

    return Semantics(
      label: 'ขั้นตอนที่ $index: ${step.text.replaceAll('**', '')}',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: WynColors.surfaceTint,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: WynColors.ink,
              ),
            ),
          ),
          const SizedBox(width: WynSpacing.space2),
          Icon(step.icon, size: 20, color: WynColors.graphite),
          const SizedBox(width: WynSpacing.space2),
          Expanded(
            child: Text.rich(
              TextSpan(children: _parseBoldMarkup(step.text, baseStyle, boldStyle)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Splits `**bold**`-marked substrings out of [text] into real bold
/// [TextSpan]s, so the design doc's markdown-style emphasis renders as
/// actual bold text instead of literal asterisks -- the copy itself
/// (words/order) stays exactly as specified, only the `**` markup syntax
/// is consumed.
List<InlineSpan> _parseBoldMarkup(String text, TextStyle base, TextStyle bold) {
  final spans = <InlineSpan>[];
  final pattern = RegExp(r'\*\*(.+?)\*\*');
  var cursor = 0;
  for (final match in pattern.allMatches(text)) {
    if (match.start > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, match.start), style: base));
    }
    spans.add(TextSpan(text: match.group(1), style: bold));
    cursor = match.end;
  }
  if (cursor < text.length) {
    spans.add(TextSpan(text: text.substring(cursor), style: base));
  }
  return spans;
}
