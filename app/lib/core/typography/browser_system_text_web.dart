import 'dart:js_interop';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

/// Flutter Web's canvas renderer cannot use the visitor's installed text fonts.
/// WYNOS therefore renders user-visible text through browser DOM surfaces.
/// Safari resolves this stack to Apple's installed system text and Apple Color
/// Emoji; Android browsers resolve to their own installed system stack.
const bool usesBrowserSystemTextDom = true;

const String _systemFontStack =
    '-apple-system, BlinkMacSystemFont, "Thonburi", "SF Pro Text", '
    '"Segoe UI", Roboto, "Noto Sans Thai", "Helvetica Neue", Arial, '
    '"Apple Color Emoji", "Segoe UI Emoji", "Noto Color Emoji", sans-serif';

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
    final spans = <BrowserSystemSpan>[];
    if (textSpan != null) {
      _flattenInlineSpan(textSpan!, null, spans);
    } else {
      spans.add(BrowserSystemSpan(text: text ?? ''));
    }
    return BrowserSystemRichText(
      spans: spans,
      style: style,
      maxLines: maxLines,
      softWrap: softWrap,
      overflow: overflow,
      textAlign: textAlign,
      semanticsLabel: semanticsLabel ?? spans.map((span) => span.text).join(),
      textDirection: textDirection,
      textHeightBehavior: textHeightBehavior,
    );
  }

  void _flattenInlineSpan(
    InlineSpan span,
    TextStyle? inheritedStyle,
    List<BrowserSystemSpan> target,
  ) {
    if (span is! TextSpan) {
      // WYNOS' web-visible rich-text call sites use TextSpan trees. Keeping an
      // explicit replacement marker here is safer than silently handing an
      // unsupported WidgetSpan back to Flutter canvas text.
      target.add(BrowserSystemSpan(text: '\uFFFC', style: inheritedStyle));
      return;
    }

    final effectiveStyle = inheritedStyle == null
        ? span.style
        : inheritedStyle.merge(span.style);
    final recognizer = span.recognizer;
    VoidCallback? onTap;
    if (recognizer is TapGestureRecognizer && recognizer.onTap != null) {
      onTap = recognizer.onTap;
    }
    if (span.text != null && span.text!.isNotEmpty) {
      target.add(
        BrowserSystemSpan(
          text: span.text!,
          style: effectiveStyle,
          onTap: onTap,
        ),
      );
    }
    for (final child in span.children ?? const <InlineSpan>[]) {
      _flattenInlineSpan(child, effectiveStyle, target);
    }
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

  String get plainText => spans.map((span) => span.text).join();

  @override
  State<BrowserSystemRichText> createState() => _BrowserSystemRichTextState();
}

class _BrowserTextMetrics {
  const _BrowserTextMetrics({
    required this.width,
    required this.height,
    required this.alphabeticBaseline,
  });

  final double width;
  final double height;
  final double alphabeticBaseline;
}

/// Reports the browser-measured alphabetic baseline to Flutter's flex
/// layout without moving the DOM platform view itself. This keeps mixed
/// author/time rows aligned exactly like normal [Text] widgets.
class _BrowserTextBaselineBox extends SingleChildRenderObjectWidget {
  const _BrowserTextBaselineBox({
    required this.alphabeticBaseline,
    required super.child,
  });

  final double alphabeticBaseline;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderBrowserTextBaselineBox(alphabeticBaseline);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderBrowserTextBaselineBox renderObject,
  ) {
    renderObject.alphabeticBaseline = alphabeticBaseline;
  }
}

class _RenderBrowserTextBaselineBox extends RenderProxyBox {
  _RenderBrowserTextBaselineBox(this._alphabeticBaseline);

  double _alphabeticBaseline;

  set alphabeticBaseline(double value) {
    if (_alphabeticBaseline == value) return;
    _alphabeticBaseline = value;
    markNeedsLayout();
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    return _alphabeticBaseline;
  }

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    return _alphabeticBaseline;
  }
}

class _BrowserSystemRichTextState extends State<BrowserSystemRichText> {
  @override
  Widget build(BuildContext context) {
    final defaultStyle = DefaultTextStyle.of(context).style;
    final effectiveStyle = defaultStyle.merge(widget.style);
    final textScaler = MediaQuery.textScalerOf(context);
    final baseFontSize = effectiveStyle.fontSize ?? 14;
    final scaledFontSize = textScaler.scale(baseFontSize);
    final direction = widget.textDirection ?? Directionality.of(context);
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final spanScale = baseFontSize == 0 ? 1.0 : scaledFontSize / baseFontSize;

    final rootAlphabeticBaseline = _measureRootAlphabeticBaseline(
      style: effectiveStyle,
      scaledFontSize: scaledFontSize,
      spanScale: spanScale,
      direction: direction,
      devicePixelRatio: devicePixelRatio,
    );

    return _BrowserTextBaselineBox(
      alphabeticBaseline: rootAlphabeticBaseline,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final metrics = _measureWithBrowser(
            constraints: constraints,
            style: effectiveStyle,
            scaledFontSize: scaledFontSize,
            spanScale: spanScale,
            direction: direction,
            devicePixelRatio: devicePixelRatio,
          );
          final key = _contentKey(
            width: metrics.width,
            height: metrics.height,
            style: effectiveStyle,
            scaledFontSize: scaledFontSize,
            direction: direction,
          );

          return _BrowserTextBaselineBox(
            alphabeticBaseline: metrics.alphabeticBaseline,
            child: Semantics(
              label: widget.semanticsLabel ?? widget.plainText,
              excludeSemantics: true,
              child: SizedBox(
                width: metrics.width,
                height: metrics.height,
                child: HtmlElementView.fromTagName(
                  key: ValueKey<String>(key),
                  tagName: 'div',
                  hitTestBehavior: PlatformViewHitTestBehavior.transparent,
                  onElementCreated: (object) {
                    final root = object as web.HTMLDivElement;
                    _configureDom(
                      root: root,
                      style: effectiveStyle,
                      scaledFontSize: scaledFontSize,
                      spanScale: spanScale,
                      direction: direction,
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  double _measureRootAlphabeticBaseline({
    required TextStyle style,
    required double scaledFontSize,
    required double spanScale,
    required TextDirection direction,
    required double devicePixelRatio,
  }) {
    final fallback = scaledFontSize * 0.82;
    final body = web.document.body;
    if (body == null) return fallback;

    final probe = web.document.createElement('div') as web.HTMLDivElement;
    probe.setAttribute('aria-hidden', 'true');
    probe.style
      ..position = 'fixed'
      ..left = '-100000px'
      ..top = '-100000px'
      ..visibility = 'hidden'
      ..pointerEvents = 'none'
      ..margin = '0'
      ..padding = '0'
      ..width = 'auto'
      ..maxWidth = 'none'
      ..height = 'auto'
      ..boxSizing = 'border-box';

    _applyBaseCss(
      probe,
      style: style,
      scaledFontSize: scaledFontSize,
      direction: direction,
      fillWidth: false,
      allowWrap: false,
    );
    probe.style.display = 'inline-block';

    final marker = web.document.createElement('span') as web.HTMLSpanElement;
    marker.style
      ..display = 'inline-block'
      ..width = '0'
      ..height = '0'
      ..margin = '0'
      ..padding = '0'
      ..verticalAlign = 'baseline';
    probe.appendChild(marker);
    _appendSpans(probe, spanScale: spanScale);
    body.appendChild(probe);

    final rect = probe.getBoundingClientRect();
    final markerRect = marker.getBoundingClientRect();
    final rawBaseline = markerRect.top - rect.top;
    probe.remove();

    final lineHeight = _snapUp(
      scaledFontSize * (style.height ?? 1.2),
      devicePixelRatio,
    );
    if (!rawBaseline.isFinite || rawBaseline <= 0) {
      return math.min(_snapUp(fallback, devicePixelRatio), lineHeight);
    }
    return math.min(_snapUp(rawBaseline, devicePixelRatio), lineHeight);
  }

  _BrowserTextMetrics _measureWithBrowser({
    required BoxConstraints constraints,
    required TextStyle style,
    required double scaledFontSize,
    required double spanScale,
    required TextDirection direction,
    required double devicePixelRatio,
  }) {
    final body = web.document.body;
    if (body == null) {
      return _fallbackMetrics(
        constraints: constraints,
        style: style,
        scaledFontSize: scaledFontSize,
        direction: direction,
        devicePixelRatio: devicePixelRatio,
      );
    }

    final probe = web.document.createElement('div') as web.HTMLDivElement;
    probe.setAttribute('aria-hidden', 'true');
    probe.style
      ..position = 'fixed'
      ..left = '-100000px'
      ..top = '-100000px'
      ..visibility = 'hidden'
      ..pointerEvents = 'none'
      ..margin = '0'
      ..padding = '0'
      ..height = 'auto'
      ..boxSizing = 'border-box';

    final tightWidth =
        constraints.hasBoundedWidth &&
        (constraints.maxWidth - constraints.minWidth).abs() < 0.001;
    if (tightWidth) {
      probe.style
        ..width = '${constraints.maxWidth}px'
        ..maxWidth = '${constraints.maxWidth}px';
    } else {
      probe.style.width = 'auto';
      if (constraints.hasBoundedWidth) {
        probe.style.maxWidth = '${constraints.maxWidth}px';
      } else {
        probe.style.maxWidth = 'none';
      }
      if (constraints.minWidth > 0) {
        probe.style.minWidth = '${constraints.minWidth}px';
      }
    }

    _applyBaseCss(
      probe,
      style: style,
      scaledFontSize: scaledFontSize,
      direction: direction,
      fillWidth: false,
      allowWrap: constraints.hasBoundedWidth,
    );

    // A zero-size inline block sits exactly on the first alphabetic
    // baseline. Measuring it gives Flutter the same baseline Safari
    // is actually using for the visible DOM text.
    final baselineMarker =
        web.document.createElement('span') as web.HTMLSpanElement;
    baselineMarker.style
      ..display = 'inline-block'
      ..width = '0'
      ..height = '0'
      ..margin = '0'
      ..padding = '0'
      ..verticalAlign = 'baseline';
    probe.appendChild(baselineMarker);
    _appendSpans(probe, spanScale: spanScale);
    body.appendChild(probe);

    final rect = probe.getBoundingClientRect();
    final markerRect = baselineMarker.getBoundingClientRect();
    final rawWidth = math.max(rect.width, 1.0);
    final rawHeight = math.max(
      rect.height,
      scaledFontSize * (style.height ?? 1.2),
    );
    final measuredWidth = constraints.constrainWidth(
      _snapUp(rawWidth, devicePixelRatio),
    );
    final measuredHeight = constraints.constrainHeight(
      _snapUp(rawHeight, devicePixelRatio),
    );
    final rawBaseline = markerRect.top - rect.top;
    final measuredBaseline = rawBaseline.isFinite && rawBaseline > 0
        ? math.min(_snapUp(rawBaseline, devicePixelRatio), measuredHeight)
        : math.min(scaledFontSize * 0.82, measuredHeight);

    probe.remove();
    return _BrowserTextMetrics(
      width: math.max(measuredWidth, 1.0),
      height: math.max(measuredHeight, 1.0),
      alphabeticBaseline: math.max(measuredBaseline, 0.0),
    );
  }

  _BrowserTextMetrics _fallbackMetrics({
    required BoxConstraints constraints,
    required TextStyle style,
    required double scaledFontSize,
    required TextDirection direction,
    required double devicePixelRatio,
  }) {
    final painter =
        TextPainter(
          text: TextSpan(
            text: widget.plainText,
            style: style.copyWith(fontSize: scaledFontSize),
          ),
          maxLines: widget.maxLines,
          ellipsis: widget.overflow == TextOverflow.ellipsis ? '…' : null,
          textDirection: direction,
          textAlign: widget.textAlign,
          textHeightBehavior: widget.textHeightBehavior,
        )..layout(
          maxWidth: constraints.hasBoundedWidth
              ? constraints.maxWidth
              : double.infinity,
        );
    final width = constraints.constrainWidth(
      _snapUp(math.max(painter.width, 1.0), devicePixelRatio),
    );
    final height = constraints.constrainHeight(
      _snapUp(
        math.max(painter.height, scaledFontSize * (style.height ?? 1.2)),
        devicePixelRatio,
      ),
    );
    return _BrowserTextMetrics(
      width: math.max(width, 1.0),
      height: math.max(height, 1.0),
      alphabeticBaseline: math.min(scaledFontSize * 0.82, height),
    );
  }

  double _snapUp(double value, double devicePixelRatio) {
    final ratio = devicePixelRatio <= 0 ? 1.0 : devicePixelRatio;
    return (value * ratio).ceilToDouble() / ratio;
  }

  String _contentKey({
    required double width,
    required double height,
    required TextStyle style,
    required double scaledFontSize,
    required TextDirection direction,
  }) {
    final spanSignature = widget.spans
        .map(
          (span) =>
              '${span.text}:${span.style?.hashCode}:${span.onTap != null}',
        )
        .join('|');
    return Object.hash(
      spanSignature,
      style.hashCode,
      scaledFontSize,
      width,
      height,
      widget.maxLines,
      widget.softWrap,
      widget.overflow,
      widget.textAlign,
      direction,
      widget.textHeightBehavior,
    ).toString();
  }

  void _configureDom({
    required web.HTMLDivElement root,
    required TextStyle style,
    required double scaledFontSize,
    required double spanScale,
    required TextDirection direction,
  }) {
    root.setAttribute('aria-hidden', 'true');
    root.style
      ..width = '100%'
      ..height = '100%'
      ..margin = '0'
      ..padding = '0'
      ..overflow = 'visible'
      ..backgroundColor = 'transparent'
      ..pointerEvents = 'none'
      ..boxSizing = 'border-box';

    final content = web.document.createElement('div') as web.HTMLDivElement;
    _applyBaseCss(
      content,
      style: style,
      scaledFontSize: scaledFontSize,
      direction: direction,
      fillWidth: true,
      allowWrap: true,
    );
    _appendSpans(content, spanScale: spanScale);
    root.appendChild(content);
  }

  void _appendSpans(web.HTMLElement parent, {required double spanScale}) {
    for (final span in widget.spans) {
      final element = web.document.createElement('span') as web.HTMLSpanElement;
      element.textContent = span.text;
      _applySpanCss(element, span.style, spanScale: spanScale);
      if (span.onTap != null) {
        element.style
          ..pointerEvents = 'auto'
          ..cursor = 'pointer';
        element.addEventListener(
          'click',
          ((web.Event event) {
            event.preventDefault();
            event.stopPropagation();
            span.onTap!.call();
          }).toJS,
        );
      }
      parent.appendChild(element);
    }
  }

  void _applyBaseCss(
    web.HTMLDivElement element, {
    required TextStyle style,
    required double scaledFontSize,
    required TextDirection direction,
    required bool fillWidth,
    required bool allowWrap,
  }) {
    final css = element.style;
    final singleLine = widget.maxLines == 1;
    final canWrap = allowWrap && widget.softWrap != false && !singleLine;
    css
      ..fontFamily = _systemFontStack
      ..fontSize = '${scaledFontSize}px'
      ..fontWeight = '${style.fontWeight?.value ?? 400}'
      ..fontStyle = style.fontStyle == FontStyle.italic ? 'italic' : 'normal'
      ..lineHeight = '${style.height ?? 1.2}'
      ..letterSpacing = '${style.letterSpacing ?? 0}px'
      ..color = _cssColor(style.color ?? const Color(0xFF000000))
      ..textAlign = _cssTextAlign(widget.textAlign, direction)
      ..direction = direction == TextDirection.rtl ? 'rtl' : 'ltr'
      ..whiteSpace = singleLine
          ? 'nowrap'
          : canWrap
          ? 'pre-wrap'
          : 'pre'
      ..overflow =
          widget.overflow == null || widget.overflow == TextOverflow.visible
          ? 'visible'
          : 'hidden'
      ..textOverflow = widget.overflow == TextOverflow.ellipsis
          ? 'ellipsis'
          : 'clip'
      ..overflowWrap = canWrap ? 'break-word' : 'normal'
      ..boxSizing = 'border-box'
      ..width = fillWidth ? '100%' : css.width
      ..margin = '0'
      ..padding = '0'
      ..backgroundColor = 'transparent'
      ..pointerEvents = 'none';
    css.setProperty('-webkit-font-smoothing', 'antialiased');

    if (widget.maxLines != null && widget.maxLines! > 1) {
      css
        ..display = '-webkit-box'
        ..overflow = 'hidden';
      css.setProperty('-webkit-box-orient', 'vertical');
      css.setProperty('-webkit-line-clamp', '${widget.maxLines}');
    } else {
      css.display = fillWidth ? 'block' : 'inline-block';
    }
  }

  void _applySpanCss(
    web.HTMLSpanElement element,
    TextStyle? style, {
    required double spanScale,
  }) {
    if (style == null) return;
    if (style.color != null) element.style.color = _cssColor(style.color!);
    if (style.fontWeight != null) {
      element.style.fontWeight = '${style.fontWeight!.value}';
    }
    if (style.fontStyle != null) {
      element.style.fontStyle = style.fontStyle == FontStyle.italic
          ? 'italic'
          : 'normal';
    }
    if (style.letterSpacing != null) {
      element.style.letterSpacing = '${style.letterSpacing}px';
    }
    if (style.fontSize != null) {
      element.style.fontSize = '${style.fontSize! * spanScale}px';
    }
    if (style.height != null) {
      element.style.lineHeight = '${style.height}';
    }
    final decoration = style.decoration;
    if (decoration != null && decoration != TextDecoration.none) {
      final values = <String>[];
      if (decoration.contains(TextDecoration.underline)) {
        values.add('underline');
      }
      if (decoration.contains(TextDecoration.lineThrough)) {
        values.add('line-through');
      }
      if (decoration.contains(TextDecoration.overline)) {
        values.add('overline');
      }
      element.style.textDecoration = values.join(' ');
    }
  }
}

class BrowserSystemTextField extends StatefulWidget {
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
  State<BrowserSystemTextField> createState() => _BrowserSystemTextFieldState();
}

class _BrowserSystemTextFieldState extends State<BrowserSystemTextField> {
  TextEditingController? _ownedController;
  FocusNode? _ownedFocusNode;
  web.HTMLElement? _element;
  double? _measuredInputHeight;
  bool _syncingDom = false;

  TextEditingController get _controller =>
      widget.controller ?? (_ownedController ??= TextEditingController());
  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownedFocusNode ??= FocusNode());
  bool get _enabled => widget.enabled ?? true;
  bool get _multiline => widget.maxLines != 1 || (widget.minLines ?? 1) > 1;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncControllerToDom);
    _focusNode.addListener(_syncFocusToDom);
  }

  @override
  void didUpdateWidget(covariant BrowserSystemTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      final oldController = oldWidget.controller ?? _ownedController;
      oldController?.removeListener(_syncControllerToDom);
      if (widget.controller != null) {
        _ownedController?.dispose();
        _ownedController = null;
      }
      _controller.addListener(_syncControllerToDom);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      final oldFocus = oldWidget.focusNode ?? _ownedFocusNode;
      oldFocus?.removeListener(_syncFocusToDom);
      if (widget.focusNode != null) {
        _ownedFocusNode?.dispose();
        _ownedFocusNode = null;
      }
      _focusNode.addListener(_syncFocusToDom);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_syncControllerToDom);
    _focusNode.removeListener(_syncFocusToDom);
    _ownedController?.dispose();
    _ownedFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final defaultStyle = DefaultTextStyle.of(context).style;
    final effectiveStyle = defaultStyle.merge(widget.style);
    final fontSize = MediaQuery.textScalerOf(context)
        .scale(effectiveStyle.fontSize ?? 16);
    final lineHeight = fontSize * (effectiveStyle.height ?? 1.25);
    final minimumLines = math.max(widget.minLines ?? 1, 1);
    final initialLines = widget.maxLines == null
        ? math.max(minimumLines, '\n'.allMatches(_controller.text).length + 1)
        : math.max(minimumLines, widget.maxLines ?? 1);
    final initialHeight = math.max(lineHeight * initialLines, lineHeight + 2);
    final inputHeight = math.max(
      _measuredInputHeight ?? initialHeight,
      initialHeight,
    );

    var decoration = widget.decoration;
    if (widget.maxLength != null &&
        decoration.counter == null &&
        decoration.counterText == null) {
      decoration = decoration.copyWith(
        counter: BrowserSystemText(
          '${_controller.text.characters.length}/${widget.maxLength}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    final direction = Directionality.of(context);
    return InputDecorator(
      decoration: decoration,
      isFocused: _focusNode.hasFocus,
      isEmpty: _controller.text.isEmpty,
      isHovering: false,
      expands: false,
      child: SizedBox(
        height: inputHeight,
        child: HtmlElementView.fromTagName(
          key: ValueKey<String>(
            'browser-input:${_multiline ? 'multi' : 'single'}:${widget.obscureText}',
          ),
          tagName: _multiline ? 'textarea' : 'input',
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
          onElementCreated: (object) {
            final element = object as web.HTMLElement;
            _element = element;
            _configureInputElement(
              element,
              effectiveStyle: effectiveStyle,
              scaledFontSize: fontSize,
              direction: direction,
            );
          },
        ),
      ),
    );
  }

  void _configureInputElement(
    web.HTMLElement element, {
    required TextStyle effectiveStyle,
    required double scaledFontSize,
    required TextDirection direction,
  }) {
    element.setAttribute('aria-hidden', 'false');
    element.setAttribute('autocomplete', 'off');
    element.setAttribute('autocapitalize', _autocapitalizeValue());
    element.setAttribute('spellcheck', widget.autocorrect ? 'true' : 'false');
    element.setAttribute('inputmode', _inputMode());
    final enterKeyHint = _enterKeyHint();
    if (enterKeyHint != null) {
      element.setAttribute('enterkeyhint', enterKeyHint);
    }
    if (!_enabled) element.setAttribute('disabled', 'disabled');
    if (widget.maxLength != null) {
      element.setAttribute('maxlength', '${widget.maxLength}');
    }
    if (!_multiline) {
      element.setAttribute('type', widget.obscureText ? 'password' : 'text');
    }

    element.style
      ..width = '100%'
      ..height = '100%'
      ..boxSizing = 'border-box'
      ..border = '0'
      ..outline = '0'
      ..margin = '0'
      ..padding = '0'
      ..resize = 'none'
      ..overflow = widget.maxLines == null ? 'hidden' : 'auto'
      ..backgroundColor = 'transparent'
      ..fontFamily = _systemFontStack
      ..fontSize = '${scaledFontSize}px'
      ..fontWeight = '${effectiveStyle.fontWeight?.value ?? 400}'
      ..fontStyle = effectiveStyle.fontStyle == FontStyle.italic
          ? 'italic'
          : 'normal'
      ..lineHeight = '${effectiveStyle.height ?? 1.25}'
      ..letterSpacing = '${effectiveStyle.letterSpacing ?? 0}px'
      ..color = _cssColor(effectiveStyle.color ?? const Color(0xFF000000))
      ..textAlign = _cssTextAlign(widget.textAlign, direction)
      ..direction = direction == TextDirection.rtl ? 'rtl' : 'ltr';
    element.style.setProperty('-webkit-font-smoothing', 'antialiased');

    _setDomValue(_controller.text);

    element.addEventListener(
      'input',
      ((web.Event event) {
        if (!mounted || _syncingDom) return;
        final rawText = _getDomValue();
        final oldValue = _controller.value;
        var nextValue = TextEditingValue(
          text: rawText,
          selection: TextSelection.collapsed(offset: rawText.length),
        );
        for (final formatter
            in widget.inputFormatters ?? const <TextInputFormatter>[]) {
          nextValue = formatter.formatEditUpdate(oldValue, nextValue);
        }
        if (widget.maxLength != null &&
            nextValue.text.characters.length > widget.maxLength!) {
          nextValue = TextEditingValue(
            text: nextValue.text.characters.take(widget.maxLength!).toString(),
            selection: TextSelection.collapsed(offset: widget.maxLength!),
          );
        }
        _controller.value = nextValue;
        if (nextValue.text != rawText) _setDomValue(nextValue.text);
        widget.onChanged?.call(nextValue.text);
        _measureMultilineHeight();
        setState(() {});
      }).toJS,
    );

    element.addEventListener(
      'focus',
      ((web.Event event) {
        if (!mounted) return;
        if (!_focusNode.hasFocus) _focusNode.requestFocus();
        setState(() {});
      }).toJS,
    );
    element.addEventListener(
      'blur',
      ((web.Event event) {
        if (!mounted) return;
        if (_focusNode.hasFocus) _focusNode.unfocus();
        setState(() {});
      }).toJS,
    );
    element.addEventListener(
      'keydown',
      ((web.Event event) {
        final keyboardEvent = event as web.KeyboardEvent;
        if (keyboardEvent.key == 'Enter' && !_multiline) {
          widget.onSubmitted?.call(_controller.text);
        }
      }).toJS,
    );

    if (widget.autofocus || _focusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) element.focus();
      });
    }
    _measureMultilineHeight();
  }

  void _syncControllerToDom() {
    if (!mounted) return;
    final current = _getDomValue();
    if (current != _controller.text) {
      _setDomValue(_controller.text);
    }
    _measureMultilineHeight();
    setState(() {});
  }

  void _syncFocusToDom() {
    final element = _element;
    if (element == null) return;
    if (_focusNode.hasFocus) {
      element.focus();
    } else {
      element.blur();
    }
    if (mounted) setState(() {});
  }

  String _getDomValue() {
    final element = _element;
    if (element == null) return '';
    if (_multiline) return (element as web.HTMLTextAreaElement).value;
    return (element as web.HTMLInputElement).value;
  }

  void _setDomValue(String value) {
    final element = _element;
    if (element == null) return;
    _syncingDom = true;
    if (_multiline) {
      (element as web.HTMLTextAreaElement).value = value;
    } else {
      (element as web.HTMLInputElement).value = value;
    }
    _syncingDom = false;
  }

  void _measureMultilineHeight() {
    if (!_multiline || widget.maxLines != null || _element == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _element == null) return;
      final height = _element!.scrollHeight.toDouble();
      if (height <= 0 || _measuredInputHeight == height) return;
      setState(() => _measuredInputHeight = height);
    });
  }

  String _inputMode() {
    final type = widget.keyboardType;
    if (type == TextInputType.emailAddress) return 'email';
    if (type == TextInputType.url) return 'url';
    if (type == TextInputType.phone) return 'tel';
    if (type == TextInputType.number ||
        type == const TextInputType.numberWithOptions()) {
      return 'numeric';
    }
    return 'text';
  }

  String _autocapitalizeValue() {
    switch (widget.textCapitalization) {
      case TextCapitalization.none:
        return 'none';
      case TextCapitalization.characters:
        return 'characters';
      case TextCapitalization.words:
        return 'words';
      case TextCapitalization.sentences:
        return 'sentences';
    }
  }

  String? _enterKeyHint() {
    switch (widget.textInputAction) {
      case TextInputAction.done:
        return 'done';
      case TextInputAction.go:
        return 'go';
      case TextInputAction.next:
        return 'next';
      case TextInputAction.previous:
        return 'previous';
      case TextInputAction.search:
        return 'search';
      case TextInputAction.send:
        return 'send';
      case TextInputAction.newline:
        return 'enter';
      default:
        return null;
    }
  }
}

class BrowserSystemTooltip extends StatefulWidget {
  const BrowserSystemTooltip({
    super.key,
    required this.message,
    required this.child,
  });

  final String message;
  final Widget child;

  @override
  State<BrowserSystemTooltip> createState() => _BrowserSystemTooltipState();
}

class _BrowserSystemTooltipState extends State<BrowserSystemTooltip> {
  OverlayEntry? _entry;

  @override
  void dispose() {
    _hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _show(),
      onExit: (_) => _hide(),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPress: _show,
        onLongPressEnd: (_) => _hide(),
        child: widget.child,
      ),
    );
  }

  void _show() {
    if (_entry != null || widget.message.isEmpty || !mounted) return;
    final overlay = Overlay.of(context);
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final origin = renderObject.localToGlobal(Offset.zero);
    final size = renderObject.size;
    _entry = OverlayEntry(
      builder: (context) => Positioned(
        left: origin.dx,
        top: origin.dy + size.height + 6,
        child: IgnorePointer(
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 240),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xE6000000),
                borderRadius: BorderRadius.circular(4),
              ),
              child: BrowserSystemText(
                widget.message,
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_entry!);
  }

  void _hide() {
    _entry?.remove();
    _entry = null;
  }
}

String _cssColor(Color color) {
  final value = color.toARGB32();
  final alpha = ((value >> 24) & 0xFF) / 255;
  final red = (value >> 16) & 0xFF;
  final green = (value >> 8) & 0xFF;
  final blue = value & 0xFF;
  return 'rgba($red, $green, $blue, $alpha)';
}

String _cssTextAlign(TextAlign align, TextDirection direction) {
  switch (align) {
    case TextAlign.left:
      return 'left';
    case TextAlign.right:
      return 'right';
    case TextAlign.center:
      return 'center';
    case TextAlign.justify:
      return 'justify';
    case TextAlign.start:
      return direction == TextDirection.rtl ? 'right' : 'left';
    case TextAlign.end:
      return direction == TextDirection.rtl ? 'left' : 'right';
  }
}
