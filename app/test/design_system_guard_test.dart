import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Beta4 §10/§22, as a check rather than a paragraph.
///
/// The Beta4 audit's colour findings were all the same shape: a value
/// that is really a system token, written out as a literal in N places.
/// `Colors.red` for the liked heart in 10 widgets. `Color(0xFFF1EFE9)`
/// in 12. `Color(0xFF2B2A26)` under two different private names. None
/// of those was *wrong* on the day it was written; they became wrong
/// when one copy drifted and nobody could see that it had. That is
/// literally WYN-076's history: two of the ten liked hearts turned
/// sapphire, and the way it was found was a screenshot from the Founder.
///
/// A doc that says "don't do that again" does not survive the next
/// feature. This does. It reads the real source, so the audit stays
/// true after Beta4 rather than describing the day it was written.
///
/// Deliberately narrow: it bans re-inlining values that now have names,
/// not hardcoded colour in general. `wyn_colors.dart` is where colours
/// are allowed to be literals -- that is its job -- and the ~70
/// intentional micro-values DS-008 formally accepted are untouched.
void main() {
  final libDir = Directory('lib');

  List<({String path, int line, String text})> matches(Pattern pattern,
      {bool Function(String path)? skip}) {
    final found = <({String path, int line, String text})>[];
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (skip != null && skip(entity.path)) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        // Comments are prose about these values (this file's own tokens
        // document their history), not uses of them.
        final trimmed = lines[i].trimLeft();
        if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;
        if (lines[i].contains(pattern)) {
          found.add((path: entity.path, line: i + 1, text: lines[i].trim()));
        }
      }
    }
    return found;
  }

  String describe(List<({String path, int line, String text})> found) =>
      found.map((m) => '  ${m.path}:${m.line}  ${m.text}').join('\n');

  bool isTokenFile(String path) => path.endsWith('wyn_colors.dart');

  test(
      'the liked-heart red is only ever WynColors.iconLikeActive, never a '
      'bare Colors.red', () {
    // The exact regression WYN-076 was: this value in many places, two
    // of which had silently stopped agreeing with the rest.
    final found = matches(RegExp(r'\bColors\.red\b'), skip: isTokenFile);
    expect(
      found,
      isEmpty,
      reason: 'Use WynColors.iconLikeActive. Found:\n${describe(found)}',
    );
  });

  test('the quiet surface tint is only ever WynColors.surfaceTint', () {
    final found = matches('0xFFF1EFE9', skip: isTokenFile);
    expect(
      found,
      isEmpty,
      reason: 'Use WynColors.surfaceTint. Found:\n${describe(found)}',
    );
  });

  test('the soft ink reading tone is only ever WynColors.inkSoft', () {
    final found = matches('0xFF2B2A26', skip: isTokenFile);
    expect(
      found,
      isEmpty,
      reason: 'Use WynColors.inkSoft. Found:\n${describe(found)}',
    );
  });

  test(
      'a Club is read through Club.identityImageUrl, never iconUrl or '
      'coverUrl directly (Beta4 §8.1)', () {
    // §8.1 forbids a Club having two images. The columns still exist
    // (dropping cover_url would blank every pre-Beta4 Club), so the rule
    // has to hold at the read sites -- which is exactly where it broke
    // before: the forms wrote one column and six widgets read the other.
    final found = matches(
      RegExp(r'\b(club|widget\.club)\.(iconUrl|coverUrl)\b'),
      // The model defines them and the getter resolves them; the
      // repository maps the raw rows. Those three are the read path.
      skip: (path) =>
          path.endsWith('club.dart') || path.endsWith('club_repository.dart'),
    );
    expect(
      found,
      isEmpty,
      reason: 'Use Club.identityImageUrl (or ClubAvatar). Found:\n'
          '${describe(found)}',
    );
  });

  test(
      'the ReDrop and Quote glyphs never come back as emoji (Beta4 §6)',
      () {
    // Scoped to these two specifically, and to the icon *slot*, not to
    // emoji in general. An emoji inside a sentence is copy -- "ยินดี
    // ต้อนรับสู่ WYNOS 👋", "📷 รูปภาพ" as a chat preview label -- and
    // §6 says nothing about copy. What §6 forbids is an emoji standing
    // in for an icon, which is what '🔄 รีโพสต์' and '💬 Quote รีโพสต์'
    // were: the labels of the two action rows that open the most
    // consequential action in the feed, in a slot where every other row
    // in the app puts an 18px IconData.
    //
    // (One emoji does sit in an icon-ish position elsewhere: the '📍'
    // before a check-in's place name on a feed card. That one is the
    // Product spec's own literal copy for WYN-098 and is left alone --
    // recorded in the icon-colour audit as an open question for the
    // Founder rather than changed here.)
    //
    // Matched as whole strings, not a character class: these code
    // points share a UTF-16 high surrogate with most other emoji, so
    // `[🔄💬]` in Dart is a class of surrogate halves that matches
    // 📷/📍/🔗/👋 too.
    final found = matches(RegExp(r'\u{1F504}|\u{1F4AC}', unicode: true),
        skip: isTokenFile);
    expect(
      found,
      isEmpty,
      reason: 'An emoji takes no colour, size, or pressed state from the '
          'icon system -- use an IconData. Found:\n${describe(found)}',
    );
  });
}
