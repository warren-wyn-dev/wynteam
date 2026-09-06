import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/design/wyn_spacing.dart';
import '../../../../core/widgets/network_thumbnail.dart';

/// Founder feedback: a chat photo sent "View Once" (like Instagram) --
/// shown for exactly [duration], then this pops itself automatically.
/// Popping early (the close button, the system back gesture) counts as
/// the one view too -- see `ConversationScreen._openViewOnceImage`'s
/// own doc comment for why the caller expires the message regardless
/// of *how* this route closes, not only on the countdown reaching zero.
///
/// Deliberately no pinch-zoom/InteractiveViewer, same "don't
/// over-engineer" posture [EvidenceImageViewer] already takes -- a
/// photo the viewer is actively racing a clock on is the last place
/// that would help.
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: Image.network(widget.signedUrl, errorBuilder: networkImageErrorBuilder),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(WynSpacing.space3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    key: const Key('view_once_close_button'),
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Semantics(
                    label: 'ปิดอัตโนมัติใน $_secondsLeft วินาที',
                    excludeSemantics: true,
                    child: Container(
                      key: const Key('view_once_countdown'),
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$_secondsLeft',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
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
