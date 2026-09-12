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
      target.add(
        BrowserSystemSpan(
          text: '\uFFFC',
          style: inheritedStyle,
        ),
      );
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
    final direction = widget.textDirection ?? Directionality.of(context);

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
      textHeightBehavior: widget.textHeightBehavior,
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
      widget.textHeightBehavior,
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
    if (style.fontSize != null) {
      element.style.fontSize = '${style.fontSize}px';
    }
    if (style.height != null) {
      element.style.lineHeight = '${style.height}';
    }
    final decoration = style.decoration;
    if (decoration != null && decoration != TextDecoration.none) {
      final values = <String>[];
      if (decoration.contains(TextDecoration.underline)) values.add('underline');
      if (decoration.contains(TextDecoration.lineThrough)) {
        values.add('line-through');
      }
      if (decoration.contains(TextDecoration.overline)) values.add('overline');
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
  FocusNode get _focusNode => widget.focusNode ?? (_ownedFocusNode ??= FocusNode());
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
    final inputHeight = math.max(_measuredInputHeight ?? initialHeight, initialHeight);

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
    if (enterKeyHint != null) element.setAttribute('enterkeyhint', enterKeyHint);
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
      ..fontStyle =
          effectiveStyle.fontStyle == FontStyle.italic ? 'italic' : 'normal'
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
        for (final formatter in widget.inputFormatters ?? const <TextInputFormatter>[]) {
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
    if (type == TextInputType.number || type == TextInputType.numberWithOptions()) {
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
