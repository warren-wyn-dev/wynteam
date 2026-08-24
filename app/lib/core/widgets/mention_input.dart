import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/hashtag/data/hashtag_repository.dart';
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
///
/// WYNOS V1.0.0 Beta requirement 7: this same field also watches for a
/// `#` immediately before the caret and shows a hashtag-suggestion
/// dropdown (tag + post count, via [HashtagRepository.suggest]) in
/// exactly the same shape as the `@` mention dropdown -- the two never
/// show at once since the caret can only ever sit inside one active
/// token at a time. [hashtagRepository] is optional -- when omitted, a
/// real Supabase-backed one is constructed lazily on first use (the
/// same "optional param, real default" shape every repository in this
/// codebase uses elsewhere), specifically *lazily*: unlike a `late
/// final` field built at construction time, nothing touches
/// `Supabase.instance` until the user actually types a `#`, so a widget
/// test that never does that (the overwhelming majority of them) is
/// never affected by whether a real Supabase session exists.
class MentionInput extends StatefulWidget {
  const MentionInput({
    super.key,
    required this.controller,
    required this.profileRepository,
    required this.onMentionedUsersChanged,
    this.hashtagRepository,
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
  final HashtagRepository? hashtagRepository;
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
  List<HashtagSuggestion> _hashtagSuggestions = [];
  final Set<String> _mentionedUserIds = {};

  // Built at most once, and only the first time a `#` token is actually
  // typed -- see the class doc comment on [MentionInput.hashtagRepository]
  // for why this must stay lazy rather than a `late final` field.
  HashtagRepository? _lazyDefaultHashtagRepository;

  HashtagRepository get _hashtagRepository =>
      widget.hashtagRepository ??
      (_lazyDefaultHashtagRepository ??=
          HashtagRepository(Supabase.instance.client));

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

  /// The query token of type [trigger] (`@` or `#`) immediately before
  /// the caret, if the caret sits inside one right now -- null when
  /// there's no [trigger] character in range, or the caret isn't a
  /// plain collapsed cursor, or a space/newline already closed the
  /// token off. Shared by mention and hashtag detection -- both are
  /// "a trigger char, then a run of non-space/newline characters, up
  /// to the caret".
  String? _activeTokenQuery(String trigger) {
    final selection = widget.controller.selection;
    if (!selection.isValid || selection.start != selection.end) return null;
    final cursor = selection.start;
    if (cursor <= 0) return null;

    final upToCursor = widget.controller.text.substring(0, cursor);
    final triggerIndex = upToCursor.lastIndexOf(trigger);
    if (triggerIndex == -1) return null;

    final between = upToCursor.substring(triggerIndex + 1);
    if (between.contains(' ') || between.contains('\n')) return null;
    return between;
  }

  void _onTextChanged() {
    _debounceTimer?.cancel();

    final mentionQuery = _activeTokenQuery('@');
    if (mentionQuery != null && mentionQuery.isNotEmpty) {
      if (_hashtagSuggestions.isNotEmpty) setState(() => _hashtagSuggestions = []);
      _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
        final results =
            await widget.profileRepository.searchProfiles(query: mentionQuery, page: 0);
        if (!mounted) return;
        setState(() => _suggestions = results);
      });
      return;
    }
    if (_suggestions.isNotEmpty) setState(() => _suggestions = []);

    final hashtagQuery = _activeTokenQuery('#');
    if (hashtagQuery != null && hashtagQuery.isNotEmpty) {
      // _hashtagRepository is only ever touched here, inside the branch
      // that already knows the user is actively typing a hashtag -- see
      // the getter's own doc comment for why that laziness matters.
      final hashtagRepository = _hashtagRepository;
      _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
        final results = await hashtagRepository.suggest(hashtagQuery);
        if (!mounted) return;
        setState(() => _hashtagSuggestions = results);
      });
      return;
    }
    if (_hashtagSuggestions.isNotEmpty) setState(() => _hashtagSuggestions = []);
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

  void _selectHashtagSuggestion(HashtagSuggestion suggestion) {
    final text = widget.controller.text;
    final cursor = widget.controller.selection.start;
    final upToCursor = text.substring(0, cursor);
    final hashIndex = upToCursor.lastIndexOf('#');
    if (hashIndex == -1) return;

    final newText =
        '${text.substring(0, hashIndex)}#${suggestion.tag} ${text.substring(cursor)}';
    final newCursor = hashIndex + suggestion.tag.length + 2;

    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );

    setState(() => _hashtagSuggestions = []);
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
        if (_hashtagSuggestions.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            margin: const EdgeInsets.only(bottom: WynSpacing.space2),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
            ),
            child: ListView.builder(
              key: const Key('hashtag_suggestions_list'),
              shrinkWrap: true,
              itemCount: _hashtagSuggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _hashtagSuggestions[index];
                return ListTile(
                  leading: Icon(Icons.tag, color: Theme.of(context).colorScheme.primary),
                  title: Text('#${suggestion.tag}'),
                  subtitle: Text('${_formatPostCount(suggestion.postCount)} โพสต์'),
                  onTap: () => _selectHashtagSuggestion(suggestion),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// "12.4K"-style compact count label for the hashtag suggestion
/// dropdown's post count -- plain digits under 1,000 (matching the
/// Product spec's own example numbers).
String _formatPostCount(int count) {
  if (count < 1000) return '$count';
  final thousands = count / 1000;
  return '${thousands.toStringAsFixed(thousands < 10 ? 1 : 0)}K';
}
