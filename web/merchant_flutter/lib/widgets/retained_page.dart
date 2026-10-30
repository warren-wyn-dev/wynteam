import 'package:flutter/widgets.dart';

/// Keeps an already visited page alive without rebuilding its widget snapshot
/// for unrelated updates while hidden. Flutter retains responsibility for
/// laying out independently dirty descendants and changed viewport constraints.
class RetainedMerchantPage extends StatefulWidget {
  const RetainedMerchantPage({
    super.key,
    required this.active,
    required this.builder,
  });

  final bool active;
  final WidgetBuilder builder;

  @override
  State<RetainedMerchantPage> createState() => _RetainedMerchantPageState();
}

class _RetainedMerchantPageState extends State<RetainedMerchantPage> {
  Widget? _snapshot;

  @override
  Widget build(BuildContext context) {
    // Re-entering a page supplies the latest controller/viewport values while
    // retaining the existing element tree, scroll position and form state.
    if (widget.active || _snapshot == null) {
      _snapshot = widget.builder(context);
    }
    return Offstage(
      offstage: !widget.active,
      child: TickerMode(
        enabled: widget.active,
        child: ExcludeFocus(
          excluding: !widget.active,
          child: RepaintBoundary(child: _snapshot!),
        ),
      ),
    );
  }
}
