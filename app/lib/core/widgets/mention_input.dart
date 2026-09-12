import 'package:wyn/core/typography/browser_system_text.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/hashtag/data/hashtag_repository.dart';
import '../../features/profile/data/profile.dart';
import '../../features/profile/data/profile_repository.dart';
import '../../features/profile/presentation/widgets/avatar_circle.dart';
import '../design/wyn_spacing.dart';

/// Drop-in replacement for a caption/content `TextField` -- WYN-021.
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
    this.style,
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
  final TextStyle? style;
  final ValueChanged<String>? onChanged;

  @override
  State<MentionInput> createState() => _MentionInputState();
}

class _MentionInputState extends State<MentionInput> {
  Timer? _debounceTimer;
  List<Profile> _suggestions = [];
  List<HashtagSuggestion> _hashtagSuggestions = [];
  final Set<String> _mentionedUserIds = {};
  HashtagRepository? _lazyDefaultHashtagRepository;

  // Incremented on every text/selection change. A request may continue after
  // its debounce timer has fired, so cancelling the timer alone cannot stop an
  // older response from overwriting a newer query's suggestions.
  int _requestGeneration = 0;

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
    _requestGeneration++;
    super.dispose();
  }

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

  bool _isCurrentRequest({
    required int generation,
    required String trigger,
    required String query,
  }) {
    return mounted &&
        generation == _requestGeneration &&
        _activeTokenQuery(trigger) == query;
  }

  void _onTextChanged() {
    _debounceTimer?.cancel();
    final generation = ++_requestGeneration;

    final mentionQuery = _activeTokenQuery('@');
    if (mentionQuery != null && mentionQuery.isNotEmpty) {
      if (_hashtagSuggestions.isNotEmpty) {
        setState(() => _hashtagSuggestions = []);
      }
      _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
        try {
          final results = await widget.profileRepository.searchProfiles(
            query: mentionQuery,
            page: 0,
          );
          if (!_isCurrentRequest(
            generation: generation,
            trigger: '@',
            query: mentionQuery,
          )) {
            return;
          }
          setState(() => _suggestions = results);
        } catch (_) {
          if (!_isCurrentRequest(
            generation: generation,
            trigger: '@',
            query: mentionQuery,
          )) {
            return;
          }
          if (_suggestions.isNotEmpty) setState(() => _suggestions = []);
        }
      });
      return;
    }
    if (_suggestions.isNotEmpty) setState(() => _suggestions = []);

    final hashtagQuery = _activeTokenQuery('#');
    if (hashtagQuery != null && hashtagQuery.isNotEmpty) {
      final hashtagRepository = _hashtagRepository;
      _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
        try {
          final results = await hashtagRepository.suggest(hashtagQuery);
          if (!_isCurrentRequest(
            generation: generation,
            trigger: '#',
            query: hashtagQuery,
          )) {
            return;
          }
          setState(() => _hashtagSuggestions = results);
        } catch (_) {
          if (!_isCurrentRequest(
            generation: generation,
            trigger: '#',
            query: hashtagQuery,
          )) {
            return;
          }
          if (_hashtagSuggestions.isNotEmpty) {
            setState(() => _hashtagSuggestions = []);
          }
        }
      });
      return;
    }
    if (_hashtagSuggestions.isNotEmpty) {
      setState(() => _hashtagSuggestions = []);
    }
  }

  void _selectSuggestion(Profile profile) {
    final text = widget.controller.text;
    final cursor = widget.controller.selection.start;
    final upToCursor = text.substring(0, cursor);
    final atIndex = upToCursor.lastIndexOf('@');
    if (atIndex == -1) return;

    final newText =
        '${text.substring(0, atIndex)}@${profile.username} ${text.substring(cursor)}';
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
        BrowserSystemTextField(
          controller: widget.controller,
          maxLength: widget.maxLength,
          maxLines: widget.maxLines,
          minLines: widget.minLines,
          enabled: widget.enabled,
          decoration: widget.decoration,
          onChanged: widget.onChanged,
          style: widget.style,
        ),
        if (_suggestions.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            margin: const EdgeInsets.only(bottom: WynSpacing.space2),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
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
                  title: BrowserSystemText(profile.nameOrUsername),
                  subtitle: BrowserSystemText('@${profile.username}'),
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
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
            ),
            child: ListView.builder(
              key: const Key('hashtag_suggestions_list'),
              shrinkWrap: true,
              itemCount: _hashtagSuggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _hashtagSuggestions[index];
                return ListTile(
                  leading: Icon(
                    Icons.tag,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: BrowserSystemText('#${suggestion.tag}'),
                  subtitle: BrowserSystemText(
                    '${_formatPostCount(suggestion.postCount)} โพสต์',
                  ),
                  onTap: () => _selectHashtagSuggestion(suggestion),
                );
              },
            ),
          ),
      ],
    );
  }
}

String _formatPostCount(int count) {
  if (count < 1000) return '$count';
  final thousands = count / 1000;
  return '${thousands.toStringAsFixed(thousands < 10 ? 1 : 0)}K';
}
