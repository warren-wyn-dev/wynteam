import '../../../core/text_utils.dart';

/// One account added to this device's account switcher (Instagram/Twitter-
/// style: multiple signed-in accounts cached locally, switch between them
/// without re-authenticating each time). Only ever captured once an
/// account is fully onboarded (see AccountSwitcherRepository's sync
/// listener) -- a guest/anonymous session or one still mid-onboarding is
/// never added, so [username] is always set by the time an account
/// reaches this store.
class StoredAccount {
  const StoredAccount({
    required this.userId,
    required this.refreshToken,
    required this.username,
    this.email,
    this.displayName,
    this.avatarUrl,
    this.isVerified = false,
  });

  /// Supabase Auth user id -- the stable key every read/write below is
  /// keyed on.
  final String userId;

  /// The single-use, rotating credential that makes quick-switching
  /// possible (`AuthRepository`-adjacent: see
  /// AccountSwitcherRepository.switchTo/startSyncingActiveSession for how
  /// this stays fresh). Never logged, never sent anywhere but Supabase's
  /// own Auth API.
  final String refreshToken;

  final String username;
  final String? email;
  final String? displayName;
  final String? avatarUrl;

  /// Same [profiles.is_verified]/VerifiedBadge semantics as
  /// [Profile.isVerified]/[Drop.authorIsVerified] -- true only for the
  /// official WYNOS account. Founder feedback: the switcher's own account
  /// list should carry the mark too, not just the profile page itself.
  final bool isVerified;

  String get nameOrUsername =>
      displayNameOrUsername(displayName: displayName, username: username);

  factory StoredAccount.fromJson(Map<String, dynamic> json) => StoredAccount(
        userId: json['userId'] as String,
        refreshToken: json['refreshToken'] as String,
        username: json['username'] as String,
        email: json['email'] as String?,
        displayName: json['displayName'] as String?,
        avatarUrl: json['avatarUrl'] as String?,
        isVerified: json['isVerified'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'refreshToken': refreshToken,
        'username': username,
        'email': email,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'isVerified': isVerified,
      };

  StoredAccount copyWith({
    String? refreshToken,
    String? username,
    String? email,
    String? displayName,
    String? avatarUrl,
    bool? isVerified,
  }) =>
      StoredAccount(
        userId: userId,
        refreshToken: refreshToken ?? this.refreshToken,
        username: username ?? this.username,
        email: email ?? this.email,
        displayName: displayName ?? this.displayName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        isVerified: isVerified ?? this.isVerified,
      );
}
