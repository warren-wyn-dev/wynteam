from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f'{label} anchor not found')
    return text.replace(old, new, 1)


web_path = Path('app/lib/core/typography/browser_system_text_web.dart')
text = web_path.read_text()
text = replace_once(
    text,
    """/// Flutter Web's canvas renderer cannot use the visitor's installed text fonts.
/// WYNOS therefore renders user-visible text through browser DOM surfaces.
/// Safari resolves this stack to Apple's installed system text and Apple Color
/// Emoji; Android browsers resolve to their own installed system stack.
const bool usesBrowserSystemTextDom = true;
""",
    """/// Flutter Web normally renders WYNOS text through browser DOM surfaces so the
/// visitor's installed system fonts are available. iOS/iPadOS WebKit is the
/// exception: a scrolling feed can accumulate hundreds of platform views, and
/// WebKit may evict/crash the page process under that pressure. On Apple mobile
/// browsers we therefore keep text inside Flutter's renderer and reserve DOM
/// platform views for surfaces that truly require native HTML controls.
final RegExp _iosWebBrowserPattern = RegExp(
  r'iPhone|iPad|iPod',
  caseSensitive: false,
);

bool get _isIosWeb {
  final navigator = web.window.navigator;
  final userAgent = navigator.userAgent;
  return _iosWebBrowserPattern.hasMatch(userAgent) ||
      (userAgent.contains('Macintosh') && navigator.maxTouchPoints > 1);
}

bool get usesBrowserSystemTextDom => !_isIosWeb;
""",
    'browser_system_text_web header',
)
text = replace_once(
    text,
    """  @override
  Widget build(BuildContext context) {
    final spans = <BrowserSystemSpan>[];
""",
    """  @override
  Widget build(BuildContext context) {
    if (!usesBrowserSystemTextDom) {
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

    final spans = <BrowserSystemSpan>[];
""",
    'BrowserSystemText build',
)
text = replace_once(
    text,
    """class _BrowserSystemRichTextState extends State<BrowserSystemRichText> {
  @override
  Widget build(BuildContext context) {
    final defaultStyle = DefaultTextStyle.of(context).style;
""",
    """class _BrowserSystemRichTextState extends State<BrowserSystemRichText> {
  final List<TapGestureRecognizer> _flutterRecognizers = [];

  @override
  void dispose() {
    _disposeFlutterRecognizers();
    super.dispose();
  }

  void _disposeFlutterRecognizers() {
    for (final recognizer in _flutterRecognizers) {
      recognizer.dispose();
    }
    _flutterRecognizers.clear();
  }

  TapGestureRecognizer _flutterRecognizerFor(VoidCallback onTap) {
    final recognizer = TapGestureRecognizer()..onTap = onTap;
    _flutterRecognizers.add(recognizer);
    return recognizer;
  }

  Widget _buildFlutterText() {
    _disposeFlutterRecognizers();
    return Text.rich(
      TextSpan(
        style: widget.style,
        children: [
          for (final span in widget.spans)
            TextSpan(
              text: span.text,
              style: span.style,
              recognizer: span.onTap == null
                  ? null
                  : _flutterRecognizerFor(span.onTap!),
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

  @override
  Widget build(BuildContext context) {
    if (!usesBrowserSystemTextDom) return _buildFlutterText();
    _disposeFlutterRecognizers();

    final defaultStyle = DefaultTextStyle.of(context).style;
""",
    'BrowserSystemRichText state',
)
web_path.write_text(text)

emoji_path = Path('app/lib/core/typography/native_emoji_web.dart')
emoji = emoji_path.read_text()
emoji = replace_once(
    emoji,
    """final RegExp _appleBrowserPattern =
    RegExp(r'iPhone|iPad|iPod|Macintosh', caseSensitive: false);

bool get shouldUseBrowserNativeEmoji =>
    _appleBrowserPattern.hasMatch(web.window.navigator.userAgent);
""",
    """final RegExp _appleBrowserPattern =
    RegExp(r'iPhone|iPad|iPod|Macintosh', caseSensitive: false);
final RegExp _iosWebBrowserPattern =
    RegExp(r'iPhone|iPad|iPod', caseSensitive: false);

bool get _isIosWeb {
  final navigator = web.window.navigator;
  final userAgent = navigator.userAgent;
  return _iosWebBrowserPattern.hasMatch(userAgent) ||
      (userAgent.contains('Macintosh') && navigator.maxTouchPoints > 1);
}

bool get shouldUseBrowserNativeEmoji =>
    !_isIosWeb && _appleBrowserPattern.hasMatch(web.window.navigator.userAgent);
""",
    'native_emoji_web gate',
)
emoji_path.write_text(emoji)

Path('app/test/ios_web_dom_stability_source_test.dart').write_text(
    """import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS Web falls back to Flutter text instead of DOM platform views', () {
    final source = File(
      'lib/core/typography/browser_system_text_web.dart',
    ).readAsStringSync();

    expect(source, contains(\"RegExp(r'iPhone|iPad|iPod'\"));
    expect(source, contains('bool get usesBrowserSystemTextDom => !_isIosWeb;'));
    expect(source, contains('if (!usesBrowserSystemTextDom)'));
    expect(source, isNot(contains('const bool usesBrowserSystemTextDom = true;')));
  });

  test('iOS Web does not create DOM platform views for emoji', () {
    final source = File(
      'lib/core/typography/native_emoji_web.dart',
    ).readAsStringSync();

    expect(source, contains('bool get _isIosWeb'));
    expect(source, contains('!_isIosWeb && _appleBrowserPattern.hasMatch'));
  });
}
"""
)
