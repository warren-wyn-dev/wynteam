import 'package:flutter/material.dart';

import '../design/wyn_colors.dart';
import '../design/wyn_spacing.dart';

/// A label-above/hairline-underline text field -- 06-edit-profile.tsx's
/// and 08-club.tsx's shared `Field` component (no Material floating-
/// label box). Originally written for Edit Profile, promoted here once
/// Create Club needed the exact same shape (both reference files define
/// the identical component independently). See EditProfileScreen's own
/// fields and CreateClubScreen's own fields for the two call sites.
class LabeledField extends StatefulWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    required this.maxLength,
    required this.helper,
    this.enabled = true,
    this.multiline = false,
    this.prefix,
    this.errorText,
    this.suffix,
    this.onChanged,
    this.onSubmitted,
    this.obscureText = false,
    this.keyboardType,
    // Edit Profile's own `Field` only reveals helper/counter while
    // focused (an animated show/hide); Create Club's `Field` shows them
    // unconditionally -- the two reference files genuinely differ here,
    // not an oversight in either.
    this.alwaysShowHelper = false,
  });

  final String label;
  final TextEditingController controller;
  final int maxLength;
  final String helper;
  final bool enabled;
  final bool multiline;
  final String? prefix;
  final String? errorText;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool alwaysShowHelper;

  /// Masks input as dots -- WYNOS Password step's password/confirm
  /// fields. Defaults to false so every pre-existing call site
  /// (EditProfileScreen, CreateClubScreen) is unaffected.
  final bool obscureText;

  /// Defaults to [TextInputType.text] (TextField's own default) when
  /// null.
  final TextInputType? keyboardType;

  @override
  State<LabeledField> createState() => _LabeledFieldState();
}

class _LabeledFieldState extends State<LabeledField> {
  final _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (_focused == _focusNode.hasFocus) return;
    setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showHelper = widget.alwaysShowHelper || _focused;

    return Padding(
      padding: const EdgeInsets.only(top: WynSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: _textStyle(
                fontSize: 13, fontWeight: FontWeight.w500, color: WynColors.ink),
          ),
          Container(
            margin: const EdgeInsets.only(top: WynSpacing.space2),
            padding: const EdgeInsets.only(bottom: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: WynColors.hairline)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (widget.prefix != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 2, bottom: 1),
                    child: Text(
                      widget.prefix!,
                      style:
                          _textStyle(fontSize: 16, color: WynColors.graphite),
                    ),
                  ),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    maxLength: widget.maxLength,
                    maxLines: widget.multiline ? 3 : 1,
                    enabled: widget.enabled,
                    obscureText: widget.obscureText,
                    keyboardType: widget.keyboardType,
                    onChanged: widget.onChanged,
                    onSubmitted: widget.onSubmitted,
                    style: _textStyle(fontSize: 16, color: WynColors.ink),
                    decoration: const InputDecoration(
                      isDense: true,
                      isCollapsed: true,
                      border: InputBorder.none,
                      counterText: '',
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (widget.suffix != null) widget.suffix!,
              ],
            ),
          ),
          if (widget.errorText != null)
            Padding(
              padding: const EdgeInsets.only(top: WynSpacing.space1),
              child: Text(
                widget.errorText!,
                style: _textStyle(fontSize: 13, color: WynColors.errorLight),
              ),
            ),
          AnimatedSize(
            duration: const Duration(milliseconds: 150),
            alignment: Alignment.topCenter,
            child: showHelper
                ? Padding(
                    padding: const EdgeInsets.only(top: WynSpacing.space1),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.helper,
                            style: _textStyle(fontSize: 13, color: WynColors.faint),
                          ),
                        ),
                        Text(
                          '${widget.controller.text.length}/${widget.maxLength}',
                          style: _textStyle(
                            fontSize: 13,
                            // Not in either reference file's own static
                            // mockup, but a real pre-existing signal worth
                            // keeping: turns error-colored once few
                            // characters remain, same 20-character
                            // threshold the Material InputDecoration
                            // counter used before this widget existed.
                            color: widget.maxLength - widget.controller.text.length < 20
                                ? WynColors.errorLight
                                : WynColors.faint,
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    );
  }
}

TextStyle _textStyle({
  required double fontSize,
  FontWeight fontWeight = FontWeight.w400,
  Color? color,
}) =>
    TextStyle(fontSize: fontSize, fontWeight: fontWeight, color: color);
