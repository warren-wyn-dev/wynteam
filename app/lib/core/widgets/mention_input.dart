import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/profile/data/profile.dart';
import '../../features/profile/data/profile_repository.dart';
import '../../features/profile/presentation/widgets/avatar_circle.dart';
import '../design/wyn_spacing.dart';

/// Drop-in replacement for a caption/content `TextField` -- WYN-021.
/// Watches for an `@` immediately before the caret with no space typed
/// after it yet, and shows a dropdown of matching users (reusing
/// ProfileRepository.searchProfiles, WYN-009, same 400ms debounce-cancel
/// discipline SearchScreen already established) directly below the
/// field. Selecting a result inserts "@username " at the caret and adds
/// that user's id to the resolved set reported via
/// [onMentionedUsersChanged] -- that resolved-id set, not a re-parse of
/// the text, is what the caller sends to the repository on submit. See
/// .wyn/docs/design/wyn-021-mention-system.md.
class MentionInput extends StatefulWidget {
  const MentionInput({
    super.key,
    required this.controller,
    required this.profileRepository,
    required this.onMentionedUsersChanged,
    this.maxLength,
    this.maxLines,
    this.minLines,
    this.enabled = true,
    this.decoration,
    this.onChanged,
  });

  final TextEditingController controller;
  final ProfileRepository profileRepository;
  final ValueChanged<Set<String>> onMentionedUsersChanged;
  final int? maxLength;
  final int? maxLines;
  final int? minLines;
  final bool enabled;
  final InputDecoration? decoration;

  /// Forwarded to the underlying TextField's onChanged -- for callers
  /// that need to react to every keystroke (e.g. enabling a submit
  /// button once there's non-whitespace content), same as they would
  /// with a plain TextField.
  final ValueChanged<String>? onChanged;

  @override
  State<MentionInput> createState() => _MentionInputState();
}

class _MentionInputState extends State<MentionInput> {
  Timer? _debounceTimer;
  List<Profile> _suggestions = [];
  final Set<String> _mentionedUserIds = {};

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// The `@query` token immediately before the caret, if the caret sits
  /// inside one right now -- null when there's no `@` in range, or the
  /// caret isn't a plain collapsed cursor, or a space/newline already
  /// closed the token off.
  String? _activeMentionQuery() {
    final selection = widget.controller.selection;
    if (!selection.isValid || selection.start != selection.end) return null;
    final cursor = selection.start;
    if (cursor <= 0) return null;

    final upToCursor = widget.controller.text.substring(0, cursor);
    final atIndex = upToCursor.lastIndexOf('@');
    if (atIndex == -1) return null;

    final between = upToCursor.substring(atIndex + 1);
    if (between.contains(' ') || between.contains('\n')) return null;
    return between;
  }

  void _onTextChanged() {
    final query = _activeMentionQuery();
    _debounceTimer?.cancel();

    if (query == null || query.isEmpty) {
      if (_suggestions.isNotEmpty) setState(() => _suggestions = []);
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      final results = await widget.profileRepository.searchProfiles(query: query, page: 0);
      if (!mounted) return;
      setState(() => _suggestions = results);
    });
  }

  void _selectSuggestion(Profile profile) {
    final text = widget.controller.text;
    final cursor = widget.controller.selection.start;
    final upToCursor = text.substring(0, cursor);
    final atIndex = upToCursor.lastIndexOf('@');
    if (atIndex == -1) return;

    final newText = '${text.substring(0, atIndex)}@${profile.username} ${text.substring(cursor)}';
    final newCursor = atIndex + profile.username.length + 2;

    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );

    _mentionedUserIds.add(profile.id);
    widget.onMentionedUsersChanged(Set.unmodifiable(_mentionedUserIds));
    setState(() => _suggestions = []);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          maxLength: widget.maxLength,
          maxLines: widget.maxLines,
          minLines: widget.minLines,
          enabled: widget.enabled,
          decoration: widget.decoration,
          onChanged: widget.onChanged,
        ),
        if (_suggestions.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            margin: const EdgeInsets.only(bottom: WynSpacing.space2),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
            ),
            child: ListView.builder(
              key: const Key('mention_suggestions_list'),
              shrinkWrap: true,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final profile = _suggestions[index];
                return ListTile(
                  leading: AvatarCircle(
                    imageUrl: profile.avatarUrl,
                    fallbackText: profile.username,
                    radius: 16,
                  ),
                  title: Text(profile.nameOrUsername),
                  subtitle: Text('@${profile.username}'),
                  onTap: () => _selectSuggestion(profile),
                );
              },
            ),
          ),
      ],
    );
  }
}
