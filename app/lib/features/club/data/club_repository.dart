import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/text_utils.dart';
import 'club.dart';
import 'club_member.dart';

const _memberProfileSelect = 'profile:profiles(username, display_name, avatar_url)';

/// Wraps the `clubs`/`club_members` reads/writes and club-media storage
/// needed for WYN-014 (Club Core). See supabase/schema.sql for the RLS
/// policies and RPC functions this relies on.
class ClubRepository {
  ClubRepository(this._client);

  final SupabaseClient _client;

  static const _bucket = 'club-media';

  // club-media is a private bucket (unlike avatars/drop-images/pop-videos,
  // which are public) -- see supabase/schema.sql, WYN-014 section, for why
  // Club posts' members-only visibility needs to be enforced at the
  // storage layer too. So cover_url/icon_url store storage *paths*, not
  // display URLs, and a fresh signed URL (scoped to whoever is actually
  // asking, re-checked against RLS at signing time) is minted on every
  // read instead of a stable URL cached forever in the DB.
  static const _signedUrlTtlSeconds = 3600;

  Future<String?> _signedUrl(String? path) async {
    if (path == null) return null;
    try {
      return await _client.storage.from(_bucket).createSignedUrl(
            path,
            _signedUrlTtlSeconds,
          );
    } catch (_) {
      // A signing failure (e.g. the object was never uploaded) shouldn't
      // crash the whole club/post -- fall back to no image instead.
      return null;
    }
  }

  Future<Club> _clubFromRow(Map<String, dynamic> row) async {
    final memberCount = await countMembers(row['id'] as String);
    final coverUrl = await _signedUrl(row['cover_url'] as String?);
    final iconUrl = await _signedUrl(row['icon_url'] as String?);
    return Club.fromMap(
      {...row, 'cover_url': coverUrl, 'icon_url': iconUrl},
      memberCount: memberCount,
    );
  }

  Future<int> countMembers(String clubId) {
    return _client
        .from('club_members')
        .count(CountOption.exact)
        .eq('club_id', clubId)
        .eq('status', 'approved');
  }

  Future<Club?> fetchClub(String clubId) async {
    final row =
        await _client.from('clubs').select().eq('id', clubId).maybeSingle();
    if (row == null) return null;
    return _clubFromRow(row);
  }

  /// Clubs the current user is an approved member of, newest-joined
  /// first -- for the CLUB section on Home.
  Future<List<Club>> fetchMyClubs() async {
    final userId = _client.auth.currentUser!.id;

    final rows = await _client
        .from('club_members')
        .select('created_at, club:clubs(*)')
        .eq('user_id', userId)
        .eq('status', 'approved')
        .order('created_at', ascending: false);

    final clubs = <Club>[];
    for (final row in rows) {
      clubs.add(await _clubFromRow(row['club'] as Map<String, dynamic>));
    }
    return clubs;
  }

  Future<List<String>> _fetchJoinedClubIds(String userId) async {
    final rows = await _client
        .from('club_members')
        .select('club_id')
        .eq('user_id', userId)
        .eq('status', 'approved');
    return rows.map((row) => row['club_id'] as String).toList();
  }

  /// Club ids the current user has a still-pending (unapproved) join
  /// request for -- WYN-056's Explore Club cards use this to show
  /// "รออนุมัติ" instead of "เข้าร่วม" for Private Clubs the user already
  /// requested to join. Unlike [_fetchJoinedClubIds] (`approved`, used to
  /// exclude already-joined Clubs from discovery entirely), a pending
  /// request doesn't exclude the Club -- it's still "discoverable", just
  /// with a different button state.
  Future<Set<String>> fetchPendingClubIds() async {
    final userId = _client.auth.currentUser!.id;
    final rows = await _client
        .from('club_members')
        .select('club_id')
        .eq('user_id', userId)
        .eq('status', 'pending');
    return rows.map((row) => row['club_id'] as String).toSet();
  }

  /// Clubs the current user hasn't joined, optionally filtered by
  /// category -- shared by [fetchPopularClubs]/[fetchNewClubs] (WYN-015
  /// Explore Clubs), which just sort/cap this differently. member count
  /// isn't a queryable column (it's computed via a separate count per
  /// club, same as [fetchMyClubs]/[fetchClub] already do), so this is a
  /// fetch-everything-then-sort-in-Dart approach rather than a scalable
  /// ranking system -- matches the Design spec's explicit "no
  /// pagination this round" scope for what's still a small Club catalog.
  Future<List<Club>> _fetchDiscoverableClubs({String? category}) async {
    final userId = _client.auth.currentUser!.id;
    final joinedIds = await _fetchJoinedClubIds(userId);

    final query = _client.from('clubs').select();
    final rows = category == null ? await query : await query.eq('category', category);

    final clubs = <Club>[];
    for (final row in rows) {
      if (joinedIds.contains(row['id'] as String)) continue;
      clubs.add(await _clubFromRow(row));
    }
    return clubs;
  }

  Future<List<Club>> fetchPopularClubs({String? category, int limit = 10}) async {
    final clubs = await _fetchDiscoverableClubs(category: category);
    clubs.sort((a, b) => b.memberCount.compareTo(a.memberCount));
    return clubs.take(limit).toList();
  }

  Future<List<Club>> fetchNewClubs({String? category, int limit = 10}) async {
    final clubs = await _fetchDiscoverableClubs(category: category);
    clubs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return clubs.take(limit).toList();
  }

  static const searchPageSize = 20;

  /// Clubs whose name contains [query] (case insensitive), newest first
  /// -- for WYN-009 Search's new Club tab. Unlike Explore, this doesn't
  /// exclude already-joined clubs (Search finds any Club by name, same
  /// as the User tab doesn't exclude already-followed users).
  Future<List<Club>> searchClubs({required String query, required int page}) async {
    final from = page * searchPageSize;
    final to = from + searchPageSize - 1;

    final rows = await _client
        .from('clubs')
        .select()
        .ilike('name', '%$query%')
        .order('created_at', ascending: false)
        .range(from, to);

    final clubs = <Club>[];
    for (final row in rows) {
      clubs.add(await _clubFromRow(row));
    }
    return clubs;
  }

  /// The current user's own club_members row (any status), or null if
  /// they've never joined/requested. Used to drive the Join/Joined/รออนุมัติ
  /// button state and role-gated UI on ClubPage.
  Future<ClubMember?> fetchMyMembership(String clubId) async {
    final userId = _client.auth.currentUser!.id;
    final row = await _client
        .from('club_members')
        .select('*, $_memberProfileSelect')
        .eq('club_id', clubId)
        .eq('user_id', userId)
        .maybeSingle();
    return row == null ? null : ClubMember.fromMap(row);
  }

  Future<List<ClubMember>> fetchApprovedMembers(String clubId) async {
    final rows = await _client
        .from('club_members')
        .select('*, $_memberProfileSelect')
        .eq('club_id', clubId)
        .eq('status', 'approved')
        .order('created_at', ascending: true);
    return rows.map((row) => ClubMember.fromMap(row)).toList();
  }

  /// Empty for anyone but that club's own owner/admin -- enforced by RLS,
  /// not a client-side check.
  Future<List<ClubMember>> fetchPendingMembers(String clubId) async {
    final rows = await _client
        .from('club_members')
        .select('*, $_memberProfileSelect')
        .eq('club_id', clubId)
        .eq('status', 'pending')
        .order('created_at', ascending: true);
    return rows.map((row) => ClubMember.fromMap(row)).toList();
  }

  Future<Club> createClub({
    required String name,
    required String description,
    String? category,
    required ClubPrivacy privacy,
    Uint8List? coverBytes,
    String? coverExtension,
    Uint8List? iconBytes,
    String? iconExtension,
  }) async {
    final userId = _client.auth.currentUser!.id;

    final row = await _client
        .from('clubs')
        .insert({
          'name': name.trim(),
          'description': normalizeOptionalText(description.trim()),
          'category': category,
          'privacy': privacy.name,
          'owner_id': userId,
        })
        .select()
        .single();
    final clubId = row['id'] as String;

    // clubs_add_owner_membership (see supabase/schema.sql) already
    // created the owner's own approved membership row synchronously as
    // part of the insert above -- no separate join call needed, and the
    // fresh club always starts with exactly 1 member.
    String? coverPath;
    String? iconPath;
    if (coverBytes != null && coverExtension != null) {
      coverPath = await _uploadClubImage(
        clubId: clubId,
        filename: 'cover.$coverExtension',
        bytes: coverBytes,
      );
      await _client.from('clubs').update({'cover_url': coverPath}).eq('id', clubId);
    }
    if (iconBytes != null && iconExtension != null) {
      iconPath = await _uploadClubImage(
        clubId: clubId,
        filename: 'icon.$iconExtension',
        bytes: iconBytes,
      );
      await _client.from('clubs').update({'icon_url': iconPath}).eq('id', clubId);
    }

    final coverUrl = await _signedUrl(coverPath);
    final iconUrl = await _signedUrl(iconPath);
    return Club.fromMap(
      {...row, 'cover_url': coverUrl, 'icon_url': iconUrl},
      memberCount: 1,
    );
  }

  Future<void> updateClubInfo({
    required String clubId,
    required String name,
    required String description,
    String? category,
  }) {
    return _client.from('clubs').update({
      'name': name.trim(),
      'description': normalizeOptionalText(description.trim()),
      'category': category,
    }).eq('id', clubId);
  }

  Future<void> updatePrivacy({
    required String clubId,
    required ClubPrivacy privacy,
  }) {
    return _client.from('clubs').update({'privacy': privacy.name}).eq('id', clubId);
  }

  Future<void> updateRules({required String clubId, required String rules}) {
    return _client
        .from('clubs')
        .update({'rules': normalizeOptionalText(rules.trim())}).eq('id', clubId);
  }

  Future<String> uploadClubCover({
    required String clubId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final path = await _uploadClubImage(
      clubId: clubId,
      filename: 'cover.$fileExtension',
      bytes: bytes,
    );
    await _client.from('clubs').update({'cover_url': path}).eq('id', clubId);
    return (await _signedUrl(path))!;
  }

  Future<String> uploadClubIcon({
    required String clubId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final path = await _uploadClubImage(
      clubId: clubId,
      filename: 'icon.$fileExtension',
      bytes: bytes,
    );
    await _client.from('clubs').update({'icon_url': path}).eq('id', clubId);
    return (await _signedUrl(path))!;
  }

  Future<String> _uploadClubImage({
    required String clubId,
    required String filename,
    required Uint8List bytes,
  }) async {
    final path = '$clubId/$filename';
    await _client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return path;
  }

  /// Public (privacy == public): joins immediately as an approved member.
  /// Private: sends a pending join request an owner/admin must approve.
  /// The status sent must match [club].privacy -- the club_members insert
  /// policy (supabase/schema.sql) rejects any other combination.
  Future<void> joinClub(Club club) async {
    final userId = _client.auth.currentUser!.id;
    await _client.from('club_members').insert({
      'club_id': club.id,
      'user_id': userId,
      'role': 'member',
      'status': club.privacy == ClubPrivacy.public ? 'approved' : 'pending',
    });
  }

  /// Leaves the club (or cancels a still-pending join request -- same
  /// operation, since both are just "delete my own club_members row").
  /// RLS blocks this for the Owner (see supabase/schema.sql).
  Future<void> leaveClub(String clubId) async {
    final userId = _client.auth.currentUser!.id;
    await _client
        .from('club_members')
        .delete()
        .eq('club_id', clubId)
        .eq('user_id', userId);
  }

  Future<void> approveMember({
    required String clubId,
    required String userId,
  }) {
    return _client.rpc('approve_club_member', params: {
      'p_club_id': clubId,
      'p_target_user_id': userId,
    });
  }

  Future<void> rejectMember({
    required String clubId,
    required String userId,
  }) {
    return _client.rpc('reject_club_member', params: {
      'p_club_id': clubId,
      'p_target_user_id': userId,
    });
  }

  Future<void> removeMember({
    required String clubId,
    required String userId,
  }) {
    return _client.rpc('remove_club_member', params: {
      'p_club_id': clubId,
      'p_target_user_id': userId,
    });
  }

  Future<void> banMember({
    required String clubId,
    required String userId,
  }) {
    return _client.rpc('ban_club_member', params: {
      'p_club_id': clubId,
      'p_target_user_id': userId,
    });
  }

  Future<void> setMemberRole({
    required String clubId,
    required String userId,
    required ClubMemberRole role,
  }) {
    return _client.rpc('set_club_member_role', params: {
      'p_club_id': clubId,
      'p_target_user_id': userId,
      'p_new_role': role.name,
    });
  }
}
