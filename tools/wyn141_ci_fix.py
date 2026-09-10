from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{path}: expected 1 match, found {count}: {old[:120]!r}")
    p.write_text(text.replace(old, new, 1))


def remove_between(path: str, start: str, end: str) -> None:
    p = Path(path)
    text = p.read_text()
    i = text.find(start)
    if i < 0:
        raise RuntimeError(f"{path}: start marker missing")
    j = text.find(end, i)
    if j < 0:
        raise RuntimeError(f"{path}: end marker missing")
    p.write_text(text[:i] + text[j:])

# Fix two duplicate declarations left by the first textual migration pass.
detail = "app/lib/features/drop/presentation/drop_detail_screen.dart"
comment_sig = "  Widget _buildCommentRow(DropComment comment, String currentUserId, {required bool isReply}) {\n"
replace_once(detail, comment_sig + comment_sig, comment_sig)
replace_once(
    detail,
    "TextStyle _textStyle({\n}\n\nTextStyle _textStyle({\n",
    "TextStyle _textStyle({\n",
)

# Fix the profile build expression duplicates, then remove legacy helpers that
# became unreachable once the Founder-final header took ownership of them.
profile = "app/lib/features/profile/presentation/view_profile_screen.dart"
replace_once(
    profile,
    "        body: FutureBuilder<_ProfileWithCounts>(\n        body: FutureBuilder<_ProfileWithCounts>(\n",
    "        body: FutureBuilder<_ProfileWithCounts>(\n",
)
replace_once(
    profile,
    "                if (!isOwnProfile)\n                  SliverToBoxAdapter(\n                if (!isOwnProfile)\n                  SliverToBoxAdapter(\n",
    "                if (!isOwnProfile)\n                  SliverToBoxAdapter(\n",
)
replace_once(profile, "import '../../home/presentation/widgets/verified_badge.dart';\n", "")
replace_once(profile, "import 'widgets/avatar_circle.dart';\n", "")
replace_once(profile, "import '../../../core/design/wyn_typography.dart';\n", "")
replace_once(
    profile,
    "  String _followButtonSemanticsLabel(Profile profile) {\n"
    "    if (_isFollowing!) return 'กำลังติดตาม กดเพื่อเลิกติดตาม';\n"
    "    if (profile.isPrivate && (_hasPendingRequest ?? false)) {\n"
    "      return 'ขอติดตามแล้ว กดเพื่อยกเลิกคำขอ';\n"
    "    }\n"
    "    return profile.isPrivate ? 'กดเพื่อขอติดตาม' : 'กดเพื่อติดตาม';\n"
    "  }\n\n",
    "",
)
remove_between(
    profile,
    "/// Beta4 §2 -- \"ชื่อที่แสดง ⌄\": the display name on your own profile,\n",
    "TextStyle _textStyle({\n",
)

# schema.sql is an executable baseline. The first patch accidentally inserted
# cover_url after the terminating semicolon; make it a real ADD COLUMN clause.
replace_once(
    "supabase/schema.sql",
    "  add column if not exists avatar_url text;\n  cover_url text,\n",
    "  add column if not exists avatar_url text,\n"
    "  add column if not exists cover_url text;\n",
)

print("WYN-141 CI correction pass applied")
