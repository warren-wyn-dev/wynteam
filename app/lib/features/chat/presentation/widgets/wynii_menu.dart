import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../../../core/design/wyn_spacing.dart';
import '../../../../core/typography/browser_system_text.dart';
import '../../data/wynii_pet.dart';

class WyniiConversationMenuRow extends StatefulWidget {
  const WyniiConversationMenuRow({
    super.key,
    required this.conversationId,
  });

  final String conversationId;

  @override
  State<WyniiConversationMenuRow> createState() =>
      _WyniiConversationMenuRowState();
}

class _WyniiConversationMenuRowState extends State<WyniiConversationMenuRow> {
  late final WyniiRepository _repository =
      WyniiRepository(Supabase.instance.client);

  WyniiConversationState? _state;
  bool _loading = true;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final state =
          await _repository.fetchConversationState(widget.conversationId);
      if (mounted) setState(() => _state = state);
    } catch (_) {
      // Keep the chat menu usable even if Wynii is temporarily unavailable.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open() async {
    if (_loading || _starting) return;
    final current = _state;
    if (current == null) return;

    WyniiPet? pet = current.pet;
    if (pet == null) {
      if (!current.isActive) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: BrowserSystemText(
              'เริ่มเลี้ยง Wynii ได้หลังจากยอมรับคำขอข้อความแล้ว',
            ),
          ),
        );
        return;
      }
      setState(() => _starting = true);
      try {
        pet = await _repository.start(widget.conversationId);
        if (mounted) {
          setState(() {
            _state = WyniiConversationState(pet: pet, isActive: true);
          });
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: BrowserSystemText(
                  'เริ่มเลี้ยง Wynii ไม่สำเร็จ ลองใหม่อีกครั้ง'),
            ),
          );
        }
        return;
      } finally {
        if (mounted) setState(() => _starting = false);
      }
    }

    if (!mounted) return;
    final navigator = Navigator.of(context);
    final parentContext = navigator.context;
    navigator.pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showModalBottomSheet<void>(
        context: parentContext,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => WyniiDetailSheet(
          conversationId: widget.conversationId,
          initialPet: pet!,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final pet = _state?.pet;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final status = pet != null && userId != null ? pet.statusFor(userId) : null;
    final label = _loading
        ? 'Wynii'
        : pet == null
            ? 'เลี้ยง Wynii ด้วยกัน'
            : 'Wynii · ${pet.ageDays} วัน';
    final subtitle = _loading
        ? 'กำลังโหลด…'
        : pet == null
            ? (_state?.isActive == false
                ? 'รอให้บทสนทนาเปิดใช้งานก่อน'
                : 'เริ่มจากไข่ของคุณสองคน')
            : status!.shortLabel;

    return InkWell(
      onTap: _loading || _starting ? null : _open,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: WynSpacing.space5,
          vertical: 11,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: WynColors.surfaceTint,
                shape: BoxShape.circle,
              ),
              child: _starting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : SizedBox(
                      width: 23,
                      height: 23,
                      child: CustomPaint(
                        painter:
                            WyniiPainter(stage: pet?.stage ?? WyniiStage.egg),
                      ),
                    ),
            ),
            const SizedBox(width: WynSpacing.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  BrowserSystemText(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: WynColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  BrowserSystemText(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: WynColors.graphite,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 19, color: WynColors.faint),
          ],
        ),
      ),
    );
  }
}

class WyniiDetailSheet extends StatefulWidget {
  const WyniiDetailSheet({
    super.key,
    required this.conversationId,
    required this.initialPet,
  });

  final String conversationId;
  final WyniiPet initialPet;

  @override
  State<WyniiDetailSheet> createState() => _WyniiDetailSheetState();
}

class _WyniiDetailSheetState extends State<WyniiDetailSheet> {
  late final WyniiRepository _repository =
      WyniiRepository(Supabase.instance.client);
  late WyniiPet _pet = widget.initialPet;
  bool _refreshing = false;

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final state =
          await _repository.fetchConversationState(widget.conversationId);
      if (mounted && state.pet != null) setState(() => _pet = state.pet!);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final status = _pet.statusFor(userId);
    final next = wyniiNextMilestone(_pet.ageDays);
    final remaining =
        next == null ? null : (next - _pet.ageDays).clamp(0, next);

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .82,
        ),
        decoration: const BoxDecoration(
          color: WynColors.paper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            WynSpacing.space5,
            10,
            WynSpacing.space5,
            WynSpacing.space5 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: WynColors.hairline,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: WynSpacing.space3),
              Row(
                children: [
                  const Expanded(
                    child: BrowserSystemText(
                      'Wynii ของเรา',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: WynColors.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'รีเฟรช',
                    onPressed: _refreshing ? null : _refresh,
                    icon: _refreshing
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 20),
                  ),
                  IconButton(
                    tooltip: 'ปิด',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: WynSpacing.space3),
              SizedBox(
                width: 174,
                height: 174,
                child: CustomPaint(painter: WyniiPainter(stage: _pet.stage)),
              ),
              const SizedBox(height: WynSpacing.space2),
              BrowserSystemText(
                '${_pet.ageDays} วัน',
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  color: WynColors.ink,
                ),
              ),
              const SizedBox(height: 3),
              BrowserSystemText(
                wyniiStageLabel(_pet.stage),
                style:
                    const TextStyle(fontSize: 13.5, color: WynColors.graphite),
              ),
              const SizedBox(height: WynSpacing.space4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(WynSpacing.space4),
                decoration: BoxDecoration(
                  color: WynColors.surfaceTint,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: WynColors.hairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BrowserSystemText(
                      status.shortLabel,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: WynColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    BrowserSystemText(
                      status.detail,
                      style: const TextStyle(
                          fontSize: 12.5, color: WynColors.graphite),
                    ),
                    const SizedBox(height: WynSpacing.space3),
                    Row(
                      children: [
                        Expanded(
                            child: _CareStatus(
                                label: 'คุณ', done: status.mineDone)),
                        const SizedBox(width: WynSpacing.space2),
                        Expanded(
                            child: _CareStatus(
                                label: 'อีกฝ่าย', done: status.otherDone)),
                      ],
                    ),
                    const SizedBox(height: WynSpacing.space4),
                    Row(
                      children: [
                        BrowserSystemText(
                          wyniiStageLabel(_pet.stage),
                          style: const TextStyle(
                              fontSize: 12, color: WynColors.graphite),
                        ),
                        const Spacer(),
                        BrowserSystemText(
                          remaining == null ? 'MAX' : 'อีก $remaining วัน',
                          style: const TextStyle(
                              fontSize: 12, color: WynColors.graphite),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: wyniiMilestoneProgress(_pet.ageDays),
                        minHeight: 7,
                        backgroundColor: WynColors.hairline,
                        valueColor:
                            const AlwaysStoppedAnimation(Color(0xFFA9A2E8)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: WynSpacing.space4),
              const BrowserSystemText(
                'ทั้งสองฝ่ายส่งอะไรก็ได้ในแชทคนละ 1 ครั้งภายใน 24 ชั่วโมง = อายุ +1 วัน\nถ้าพลาดรอบ อายุจะไม่ลดและไม่รีเซ็ต',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: WynColors.graphite,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CareStatus extends StatelessWidget {
  const _CareStatus({required this.label, required this.done});

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space3),
      decoration: BoxDecoration(
        color: WynColors.paper,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: BrowserSystemText(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: WynColors.ink),
            ),
          ),
          BrowserSystemText(
            done ? '✓ ส่งแล้ว' : 'รอ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: done ? FontWeight.w700 : FontWeight.w500,
              color: done ? const Color(0xFF1E8D54) : WynColors.faint,
            ),
          ),
        ],
      ),
    );
  }
}

class WyniiPainter extends CustomPainter {
  WyniiPainter({required this.stage});

  final WyniiStage stage;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final unit = size.shortestSide / 180;
    final glow = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFC7B4F7), Color(0xFF91C9FF), Color(0xFFC4A9EF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);
    final outline = Paint()
      ..color = const Color(0xFFDCDDEA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * unit;

    if (stage == WyniiStage.egg || stage == WyniiStage.hatching) {
      final eggPath = Path()
        ..moveTo(center.dx, 12 * unit)
        ..cubicTo(
            45 * unit, 13 * unit, 22 * unit, 68 * unit, 22 * unit, 108 * unit)
        ..cubicTo(
            22 * unit, 148 * unit, 51 * unit, 169 * unit, center.dx, 169 * unit)
        ..cubicTo(129 * unit, 169 * unit, 158 * unit, 148 * unit, 158 * unit,
            108 * unit)
        ..cubicTo(
            158 * unit, 68 * unit, 135 * unit, 13 * unit, center.dx, 12 * unit)
        ..close();
      final eggPaint = Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.25, -.4),
          radius: 1.1,
          colors: [Colors.white, Color(0xFFF0EDFF), Color(0xFFBCD9FF)],
        ).createShader(Offset.zero & size);
      canvas.drawPath(eggPath, eggPaint);
      canvas.drawPath(eggPath, outline);
      if (stage == WyniiStage.hatching) {
        final crack = Path()
          ..moveTo(37 * unit, 91 * unit)
          ..lineTo(61 * unit, 77 * unit)
          ..lineTo(82 * unit, 96 * unit)
          ..lineTo(101 * unit, 68 * unit)
          ..lineTo(122 * unit, 94 * unit)
          ..lineTo(146 * unit, 80 * unit);
        canvas.drawPath(
          crack,
          Paint()
            ..color = const Color(0xFFA99CCB)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2 * unit
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      }
      _drawHeart(canvas, Offset(center.dx, 105 * unit), 23 * unit, glow);
      return;
    }

    final grown = stage == WyniiStage.growing ||
        stage == WyniiStage.mature ||
        stage == WyniiStage.max;
    final mature = stage == WyniiStage.mature || stage == WyniiStage.max;

    if (grown) {
      final tail = Path()
        ..moveTo(133 * unit, 119 * unit)
        ..cubicTo(170 * unit, 112 * unit, 178 * unit, 146 * unit, 153 * unit,
            158 * unit)
        ..cubicTo(137 * unit, 165 * unit, 124 * unit, 150 * unit, 126 * unit,
            136 * unit)
        ..cubicTo(140 * unit, 144 * unit, 151 * unit, 138 * unit, 148 * unit,
            129 * unit)
        ..cubicTo(145 * unit, 121 * unit, 138 * unit, 119 * unit, 133 * unit,
            119 * unit)
        ..close();
      canvas.drawPath(tail, glow);
    }

    final bodyPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-.2, -.35),
        radius: 1,
        colors: [Colors.white, Color(0xFFFBFBFF), Color(0xFFE9ECFF)],
      ).createShader(Offset.zero & size);

    final leftEar = Path()
      ..moveTo(58 * unit, 58 * unit)
      ..lineTo(27 * unit, 31 * unit)
      ..quadraticBezierTo(19 * unit, 25 * unit, 22 * unit, 42 * unit)
      ..lineTo(37 * unit, 80 * unit)
      ..close();
    final rightEar = Path()
      ..moveTo(122 * unit, 58 * unit)
      ..lineTo(153 * unit, 31 * unit)
      ..quadraticBezierTo(161 * unit, 25 * unit, 158 * unit, 42 * unit)
      ..lineTo(143 * unit, 80 * unit)
      ..close();
    canvas.drawPath(leftEar, bodyPaint);
    canvas.drawPath(rightEar, bodyPaint);
    canvas.drawPath(leftEar, outline);
    canvas.drawPath(rightEar, outline);

    if (mature) {
      canvas.drawPath(
        Path()
          ..moveTo(48 * unit, 58 * unit)
          ..lineTo(31 * unit, 44 * unit)
          ..lineTo(39 * unit, 69 * unit)
          ..close(),
        glow,
      );
      canvas.drawPath(
        Path()
          ..moveTo(132 * unit, 58 * unit)
          ..lineTo(149 * unit, 44 * unit)
          ..lineTo(141 * unit, 69 * unit)
          ..close(),
        glow,
      );
    }

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, 101 * unit),
        width: (grown ? 116 : 106) * unit,
        height: (grown ? 121 : 112) * unit,
      ),
      bodyPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, 101 * unit),
        width: (grown ? 116 : 106) * unit,
        height: (grown ? 121 : 112) * unit,
      ),
      outline,
    );

    final eyePaint = Paint()..color = const Color(0xFF4A4D89);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(68 * unit, 90 * unit),
          width: 23 * unit,
          height: 29 * unit),
      eyePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(112 * unit, 90 * unit),
          width: 23 * unit,
          height: 29 * unit),
      eyePaint,
    );
    canvas.drawCircle(
        Offset(64 * unit, 84 * unit), 4 * unit, Paint()..color = Colors.white);
    canvas.drawCircle(
        Offset(108 * unit, 84 * unit), 4 * unit, Paint()..color = Colors.white);

    final mouth = Paint()
      ..color = const Color(0xFF77718B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * unit
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(center.dx, 108 * unit),
          width: 20 * unit,
          height: 12 * unit),
      .15,
      2.85,
      false,
      mouth,
    );
    _drawHeart(canvas, Offset(center.dx, 135 * unit), 22 * unit, glow);

    if (stage == WyniiStage.max) {
      canvas.drawCircle(Offset(28 * unit, 95 * unit), 3 * unit, glow);
      canvas.drawCircle(Offset(153 * unit, 82 * unit), 2.5 * unit, glow);
      canvas.drawCircle(Offset(137 * unit, 36 * unit), 2 * unit, glow);
      final crown = Path()
        ..moveTo(75 * unit, 45 * unit)
        ..quadraticBezierTo(90 * unit, 23 * unit, 105 * unit, 45 * unit)
        ..quadraticBezierTo(96 * unit, 40 * unit, 90 * unit, 51 * unit)
        ..quadraticBezierTo(84 * unit, 40 * unit, 75 * unit, 45 * unit)
        ..close();
      canvas.drawPath(crown, glow);
    }
  }

  void _drawHeart(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path()
      ..moveTo(center.dx, center.dy + size * .42)
      ..cubicTo(
        center.dx - size * .58,
        center.dy + size * .06,
        center.dx - size * .56,
        center.dy - size * .44,
        center.dx - size * .22,
        center.dy - size * .44,
      )
      ..cubicTo(
        center.dx,
        center.dy - size * .44,
        center.dx,
        center.dy - size * .22,
        center.dx,
        center.dy - size * .12,
      )
      ..cubicTo(
        center.dx,
        center.dy - size * .22,
        center.dx,
        center.dy - size * .44,
        center.dx + size * .22,
        center.dy - size * .44,
      )
      ..cubicTo(
        center.dx + size * .56,
        center.dy - size * .44,
        center.dx + size * .58,
        center.dy + size * .06,
        center.dx,
        center.dy + size * .42,
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WyniiPainter oldDelegate) =>
      oldDelegate.stage != stage;
}
