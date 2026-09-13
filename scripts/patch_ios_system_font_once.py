from pathlib import Path

app = Path(__file__).resolve().parents[1] / 'app'
path = app / 'lib/core/typography/browser_system_text_web.dart'
text = path.read_text()

marker = "bool get usesBrowserSystemTextDom => !_isIosWeb;\n\n"
helper = """bool get usesBrowserSystemTextDom => !_isIosWeb;

const String _cupertinoSystemTextFontFamily = 'CupertinoSystemText';
const String _cupertinoSystemDisplayFontFamily = 'CupertinoSystemDisplay';

TextStyle _iosSystemFontStyle(BuildContext context, TextStyle? style) {
  final effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
  final fontSize = effectiveStyle.fontSize ?? 14;
  return (style ?? const TextStyle()).copyWith(
    fontFamily: fontSize >= 20
        ? _cupertinoSystemDisplayFontFamily
        : _cupertinoSystemTextFontFamily,
  );
}

"""
if marker not in text:
    raise SystemExit('system font helper marker not found')
text = text.replace(marker, helper, 1)

old_fallback = """    if (!usesBrowserSystemTextDom) {
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
"""
new_fallback = """    if (!usesBrowserSystemTextDom) {
      final iosStyle = _iosSystemFontStyle(context, style);
      if (textSpan != null) {
        return Text.rich(
          textSpan!,
          style: iosStyle,
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
        style: iosStyle,
        maxLines: maxLines,
        softWrap: softWrap,
        overflow: overflow,
        textAlign: textAlign,
        semanticsLabel: semanticsLabel,
        textDirection: textDirection,
        textHeightBehavior: textHeightBehavior,
      );
    }
"""
if old_fallback not in text:
    raise SystemExit('BrowserSystemText fallback block not found')
text = text.replace(old_fallback, new_fallback, 1)

old_rich = """  Widget _buildFlutterText() {
    _disposeFlutterRecognizers();
    return Text.rich(
      TextSpan(
        style: widget.style,
"""
new_rich = """  Widget _buildFlutterText() {
    _disposeFlutterRecognizers();
    final iosStyle = _iosSystemFontStyle(context, widget.style);
    return Text.rich(
      TextSpan(
        style: iosStyle,
"""
if old_rich not in text:
    raise SystemExit('BrowserSystemRichText fallback block not found')
text = text.replace(old_rich, new_rich, 1)
path.write_text(text)

test_path = app / 'test/ios_web_dom_stability_source_test.dart'
test = test_path.read_text()
anchor = "    expect(source, contains('if (!usesBrowserSystemTextDom)'));\n"
addition = """    expect(source, contains('if (!usesBrowserSystemTextDom)'));
    expect(source, contains("'CupertinoSystemText'"));
    expect(source, contains("'CupertinoSystemDisplay'"));
    expect(source, contains('_iosSystemFontStyle(context, style)'));
"""
if anchor not in test:
    raise SystemExit('regression test anchor not found')
test = test.replace(anchor, addition, 1)
test_path.write_text(test)
