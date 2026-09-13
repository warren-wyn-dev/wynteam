import 'package:wyn/core/typography/browser_system_text.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../../../core/design/wyn_spacing.dart';
import '../../../../core/widgets/network_thumbnail.dart';

/// Chat "View Once" viewer: one distraction-free dark canvas, a compact
/// countdown pill, and the same auto-close / early-close semantics as before.
class ViewOnceImageViewer extends StatefulWidget {
  const ViewOnceImageViewer({
    super.key,
    required this.signedUrl,
    this.duration = const Duration(seconds: 8),
  });

  final String signedUrl;
  final Duration duration;

  @override
  State<ViewOnceImageViewer> createState() => _ViewOnceImageViewerState();
}

class _ViewOnceImageViewerState extends State<ViewOnceImageViewer> {
  late int _secondsLeft = widget.duration.inSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  void _tick(Timer timer) {
    if (!mounted) return;
    if (_secondsLeft <= 1) {
      timer.cancel();
      Navigator.of(context).pop();
      return;
    }
    setState(() => _secondsLeft -= 1);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.duration.inSeconds == 0
        ? 0.0
        : _secondsLeft / widget.duration.inSeconds;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: Image.network(
                widget.signedUrl,
                fit: BoxFit.contain,
                errorBuilder: networkImageErrorBuilder,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                WynSpacing.space3,
                WynSpacing.space2,
                WynSpacing.space3,
                0,
              ),
              child: Row(
                children: [
                  Material(
                    color: WynColors.imageScrimStrong,
                    shape: const CircleBorder(),
                    child: BrowserSystemTooltip(
                        message: 'ปิด',
                        child: BrowserSystemTooltip(
                            message: null,
                            child: IconButton(
                              key: const Key('view_once_close_button'),
                              icon: const Icon(Icons.close,
                                  color: WynColors.paper, size: 21),
                              onPressed: () => Navigator.of(context).pop(),
                            ))),
                  ),
                  const Spacer(),
                  Semantics(
                    label: 'ปิดอัตโนมัติใน $_secondsLeft วินาที',
                    excludeSemantics: true,
                    child: Container(
                      key: const Key('view_once_countdown'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: WynSpacing.space3,
                        vertical: WynSpacing.space2,
                      ),
                      decoration: BoxDecoration(
                        color: WynColors.imageScrimStrong,
                        borderRadius:
                            BorderRadius.circular(WynSpacing.radiusFull),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.filter_1_outlined,
                              size: 15, color: WynColors.paper),
                          const SizedBox(width: WynSpacing.space1),
                          BrowserSystemText(
                            '$_secondsLeft',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: WynColors.paper,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: WynSpacing.space4,
            right: WynSpacing.space4,
            bottom: WynSpacing.space4,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 3,
                      backgroundColor: WynColors.graphite,
                      color: WynColors.paper,
                    ),
                  ),
                  const SizedBox(height: WynSpacing.space2),
                  const BrowserSystemText(
                    'รูปนี้จะหายหลังจากเปิดดู',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: WynColors.faint),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
