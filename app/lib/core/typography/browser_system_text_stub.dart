import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// True only on Flutter Web, where WYNOS can hand selected text surfaces to
/// the browser DOM so Safari/Chrome use the visitor's installed system font
/// and emoji renderer. Native iOS/Android stay normal Flutter text.
const bool usesBrowserSystemTextDom = false;

class BrowserSystemSpan {
  const BrowserSystemSpan({
    required this.text,
    this.style,
    this.onTap,
  });

  final String text;
  final TextStyle? style;
  final VoidCallback? onTap;
}

class BrowserSystemText extends StatelessWidget {
  const BrowserSystemText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign = TextAlign.start,
    this.semanticsLabel,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign textAlign;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      semanticsLabel: semanticsLabel,
    );
  }
}

class BrowserSystemRichText extends StatefulWidget {
  const BrowserSystemRichText({
    super.key,
    required this.spans,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign = TextAlign.start,
    this.semanticsLabel,
  });

  final List<BrowserSystemSpan> spans;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign textAlign;
  final String? semanticsLabel;

  @override
  State<BrowserSystemRichText> createState() => _BrowserSystemRichTextState();
}

class _BrowserSystemRichTextState extends State<BrowserSystemRichText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  TapGestureRecognizer _recognizerFor(VoidCallback onTap) {
    final recognizer = TapGestureRecognizer()..onTap = onTap;
    _recognizers.add(recognizer);
    return recognizer;
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();

    return Text.rich(
      TextSpan(
        style: widget.style,
        children: [
          for (final span in widget.spans)
            TextSpan(
              text: span.text,
              style: span.style,
              recognizer:
                  span.onTap == null ? null : _recognizerFor(span.onTap!),
            ),
        ],
      ),
      maxLines: widget.maxLines,
      overflow: widget.overflow ?? TextOverflow.clip,
      textAlign: widget.textAlign,
      semanticsLabel: widget.semanticsLabel,
    );
  }
}
