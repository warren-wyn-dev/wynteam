import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// True only on Flutter Web, where WYNOS can hand text surfaces to the browser
/// DOM so Safari/Chrome use the visitor's installed system font and emoji
/// renderer. Native iOS/Android stay normal Flutter text.
const bool usesBrowserSystemTextDom = false;

class BrowserSystemSpan {
  const BrowserSystemSpan({required this.text, this.style, this.onTap});

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
    this.softWrap,
    this.overflow,
    this.textAlign = TextAlign.start,
    this.semanticsLabel,
    this.textDirection,
    this.textHeightBehavior,
  }) : textSpan = null;

  const BrowserSystemText.rich(
    InlineSpan this.textSpan, {
    super.key,
    this.style,
    this.maxLines,
    this.softWrap,
    this.overflow,
    this.textAlign = TextAlign.start,
    this.semanticsLabel,
    this.textDirection,
    this.textHeightBehavior,
  }) : text = null;

  final String? text;
  final InlineSpan? textSpan;
  final TextStyle? style;
  final int? maxLines;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextAlign textAlign;
  final String? semanticsLabel;
  final TextDirection? textDirection;
  final TextHeightBehavior? textHeightBehavior;

  @override
  Widget build(BuildContext context) {
    if (textSpan != null) {
      return Text.rich(
        textSpan!,
        style: style,
        maxLines: maxLines,
        softWrap: softWrap,
        overflow: overflow ?? TextOverflow.clip,
        textAlign: textAlign,
        semanticsLabel: semanticsLabel,
        textDirection: textDirection,
        textHeightBehavior: textHeightBehavior,
      );
    }
    return Text(
      text ?? '',
      style: style,
      maxLines: maxLines,
      softWrap: softWrap,
      overflow: overflow,
      textAlign: textAlign,
      semanticsLabel: semanticsLabel,
      textDirection: textDirection,
      textHeightBehavior: textHeightBehavior,
    );
  }
}

class BrowserSystemRichText extends StatefulWidget {
  const BrowserSystemRichText({
    super.key,
    required this.spans,
    this.style,
    this.maxLines,
    this.softWrap,
    this.overflow,
    this.textAlign = TextAlign.start,
    this.semanticsLabel,
    this.textDirection,
    this.textHeightBehavior,
  });

  final List<BrowserSystemSpan> spans;
  final TextStyle? style;
  final int? maxLines;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextAlign textAlign;
  final String? semanticsLabel;
  final TextDirection? textDirection;
  final TextHeightBehavior? textHeightBehavior;

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
      softWrap: widget.softWrap,
      overflow: widget.overflow ?? TextOverflow.clip,
      textAlign: widget.textAlign,
      semanticsLabel: widget.semanticsLabel,
      textDirection: widget.textDirection,
      textHeightBehavior: widget.textHeightBehavior,
    );
  }
}

/// Native compatibility implementation. On iOS/Android this deliberately uses
/// Flutter's normal editable text path so the platform keeps its native font
/// and emoji behavior.
class BrowserSystemTextField extends StatelessWidget {
  const BrowserSystemTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.decoration = const InputDecoration(),
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.style,
    this.textAlign = TextAlign.start,
    this.autofocus = false,
    this.obscureText = false,
    this.autocorrect = true,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.onChanged,
    this.onSubmitted,
    this.inputFormatters,
    this.enabled,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final InputDecoration decoration;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final TextStyle? style;
  final TextAlign textAlign;
  final bool autofocus;
  final bool obscureText;
  final bool autocorrect;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final bool? enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      decoration: decoration,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      style: style,
      textAlign: textAlign,
      autofocus: autofocus,
      obscureText: obscureText,
      autocorrect: autocorrect,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      inputFormatters: inputFormatters,
      enabled: enabled,
    );
  }
}

/// Native compatibility wrapper for the one custom tooltip surface that WYNOS
/// owns. Web provides its own DOM overlay implementation.
class BrowserSystemTooltip extends StatelessWidget {
  const BrowserSystemTooltip({
    super.key,
    required this.message,
    required this.child,
  });

  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) => Tooltip(message: message, child: child);
}
