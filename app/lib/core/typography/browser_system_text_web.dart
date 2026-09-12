import 'dart:js_interop';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:web/web.dart' as web;

/// Flutter Web's canvas renderer cannot use the visitor's installed text fonts.
/// For the social surfaces that must visually match the device, render through
/// the browser DOM instead. Safari then uses Apple's installed system text and
/// Apple Color Emoji; Android browsers resolve to their own system stack.
const bool usesBrowserSystemTextDom = true;

const String _systemFontStack =
    '-apple-system, BlinkMacSystemFont, "Thonburi", "SF Pro Text", '
    '"Segoe UI", Roboto, "Noto Sans Thai", "Helvetica Neue", Arial, '
    '"Apple Color Emoji", "Segoe UI Emoji", "Noto Color Emoji", sans-serif';

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
    this.softWrap,
    this.overflow,
    this.textAlign = TextAlign.start,
    this.semanticsLabel,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextAlign textAlign;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return BrowserSystemRichText(
      spans: [BrowserSystemSpan(text: text)],
      style: style,
      maxLines: maxLines,
      softWrap: softWrap,
      overflow: overflow,
      textAlign: textAlign,
      semanticsLabel: semanticsLabel ?? text,
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
  });

  final List<BrowserSystemSpan> spans;
  final TextStyle? style;
  final int? maxLines;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextAlign textAlign;
  final String? semanticsLabel;

  String get plainText => spans.map((span) => span.text).join();

  @override
  State<BrowserSystemRichText> createState() => _BrowserSystemRichTextState();
}

class _BrowserSystemRichTextState extends State<BrowserSystemRichText> {
  web.ResizeObserver? _resizeObserver;
  double? _measuredHeight;
  String? _measurementKey;

  @override
  void dispose() {
    _resizeObserver?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final defaultStyle = DefaultTextStyle.of(context).style;
    final effectiveStyle = defaultStyle.merge(widget.style);
    final textScaler = MediaQuery.textScalerOf(context);
    final baseFontSize = effectiveStyle.fontSize ?? 14;
    final scaledFontSize = textScaler.scale(baseFontSize);
    final direction = Directionality.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = _resolveWidth(
          constraints: constraints,
          style: effectiveStyle,
          scaledFontSize: scaledFontSize,
          direction: direction,
        );
        final estimatedHeight = _estimateHeight(
          width: width,
          style: effectiveStyle,
          scaledFontSize: scaledFontSize,
          direction: direction,
        );
        final key = _contentKey(
          width: width,
          style: effectiveStyle,
          scaledFontSize: scaledFontSize,
          direction: direction,
        );
        if (_measurementKey != key) {
          _measurementKey = key;
          _measuredHeight = estimatedHeight;
        }

        final height = math.max(_measuredHeight ?? estimatedHeight, 1.0);
        return Semantics(
          label: widget.semanticsLabel ?? widget.plainText,
          excludeSemantics: true,
          child: SizedBox(
            width: width,
            height: height,
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
                  direction: direction,
                );
              },
            ),
          ),
        );
      },
    );
  }

  double _resolveWidth({
    required BoxConstraints constraints,
    required TextStyle style,
    required double scaledFontSize,
    required TextDirection direction,
  }) {
    if (constraints.hasBoundedWidth) {
      return math.max(constraints.maxWidth, 1);
    }

    final painter = TextPainter(
      text: TextSpan(
        text: widget.plainText,
        style: style.copyWith(fontSize: scaledFontSize),
      ),
      maxLines: 1,
      textDirection: direction,
    )..layout();
    return math.max(painter.width.ceilToDouble() + 2, 1);
  }

  double _estimateHeight({
    required double width,
    required TextStyle style,
    required double scaledFontSize,
    required TextDirection direction,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: widget.plainText,
        style: style.copyWith(fontSize: scaledFontSize),
      ),
      maxLines: widget.maxLines,
      ellipsis: widget.overflow == TextOverflow.ellipsis ? '…' : null,
      textDirection: direction,
      textAlign: widget.textAlign,
    )..layout(maxWidth: width);
    final explicitLineHeight = scaledFontSize * (style.height ?? 1.2);
    return math.max(painter.height, explicitLineHeight).ceilToDouble();
  }

  String _contentKey({
    required double width,
    required TextStyle style,
    required double scaledFontSize,
    required TextDirection direction,
  }) {
    final spanSignature = widget.spans
        .map((span) =>
            '${span.text}:${span.style?.hashCode}:${span.onTap != null}')
        .join('|');
    return Object.hash(
      spanSignature,
      style.hashCode,
      scaledFontSize,
      width,
      widget.maxLines,
      widget.overflow,
      widget.textAlign,
      direction,
    ).toString();
  }

  void _configureDom({
    required web.HTMLDivElement root,
    required TextStyle style,
    required double scaledFontSize,
    required TextDirection direction,
  }) {
    _resizeObserver?.disconnect();

    root.setAttribute('aria-hidden', 'true');
    root.style
      ..width = '100%'
      ..height = '100%'
      ..margin = '0'
      ..padding = '0'
      ..overflow = 'visible'
      ..backgroundColor = 'transparent'
      ..pointerEvents = 'none';

    final content = web.document.createElement('div') as web.HTMLDivElement;
    _applyBaseCss(
      content,
      style: style,
      scaledFontSize: scaledFontSize,
      direction: direction,
    );

    for (final span in widget.spans) {
      final element = web.document.createElement('span') as web.HTMLSpanElement;
      element.textContent = span.text;
      _applySpanCss(element, span.style);
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
      content.appendChild(element);
    }
    root.appendChild(content);

    final observer = web.ResizeObserver((
      JSArray<web.ResizeObserverEntry> entries,
      web.ResizeObserver observer,
    ) {
      if (!mounted || !root.isConnected) return;
      final measured = content.getBoundingClientRect().height;
      if (measured <= 0) return;
      final nextHeight = measured.ceilToDouble();
      if ((_measuredHeight ?? 0) == nextHeight) return;
      setState(() => _measuredHeight = nextHeight);
    }.toJS);
    _resizeObserver = observer;
    observer.observe(content);
  }

  void _applyBaseCss(
    web.HTMLDivElement element, {
    required TextStyle style,
    required double scaledFontSize,
    required TextDirection direction,
  }) {
    final css = element.style;
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
      ..whiteSpace = widget.softWrap == false || widget.maxLines == 1
          ? 'nowrap'
          : 'pre-wrap'
      ..overflow =
          widget.overflow == null || widget.overflow == TextOverflow.visible
              ? 'visible'
              : 'hidden'
      ..textOverflow =
          widget.overflow == TextOverflow.ellipsis ? 'ellipsis' : 'clip'
      ..overflowWrap = 'break-word'
      ..boxSizing = 'border-box'
      ..width = '100%'
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
      css.display = 'block';
    }
  }

  void _applySpanCss(web.HTMLSpanElement element, TextStyle? style) {
    if (style == null) return;
    if (style.color != null) element.style.color = _cssColor(style.color!);
    if (style.fontWeight != null) {
      element.style.fontWeight = '${style.fontWeight!.value}';
    }
    if (style.fontStyle != null) {
      element.style.fontStyle =
          style.fontStyle == FontStyle.italic ? 'italic' : 'normal';
    }
    if (style.letterSpacing != null) {
      element.style.letterSpacing = '${style.letterSpacing}px';
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
}
