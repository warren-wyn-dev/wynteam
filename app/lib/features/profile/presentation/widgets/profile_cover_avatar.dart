import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'avatar_circle.dart';
import '../../../../core/design/wyn_spacing.dart';

/// The cover-image-with-overlapping-avatar header used by both
/// [ViewProfileScreen] (read-only) and [EditProfileScreen] (tappable, with
/// camera badges) -- one widget instead of two hand-written `Stack`s so
/// they stay pixel-identical (WYSIWYG), per the WYN-024 design spec's R1
/// section ("โครงสร้าง Stack เดียวกับ View Profile เป๊ะ"). Mirrors the
/// composition `ClubPage`/`EditClubInfoScreen` already use for Club's own
/// cover+icon header (WYN-014) -- 140px fixed-height rounded cover, avatar
/// overlapping its bottom edge -- except the avatar here is centered
/// horizontally rather than left-aligned, per that same spec.
///
/// This widget's own height already reserves room for the avatar's
/// overhang below the cover (rather than the avatar visually overflowing
/// past this widget's box via `clipBehavior: Clip.none` the way
/// `ClubPage._buildHeader()` does) -- a caller placing this directly in a
/// `Column` gets the correct trailing gap to the next sibling for free,
/// without needing an extra compensating `SizedBox` of its own.
class ProfileCoverAvatar extends StatelessWidget {
  const ProfileCoverAvatar({
    super.key,
    required this.coverUrl,
    this.coverBytes,
    required this.avatarUrl,
    this.avatarBytes,
    required this.fallbackText,
    this.coverSemanticsLabel,
    this.onTapCover,
    this.onTapAvatar,
  });

  /// The saved cover URL, read straight from `profiles.cover_url`.
  final String? coverUrl;

  /// A just-picked-but-not-yet-uploaded cover image, previewed in place of
  /// [coverUrl] when set. Edit Profile only -- always null from View
  /// Profile's read-only usage.
  final Uint8List? coverBytes;

  final String? avatarUrl;

  /// A just-picked-but-not-yet-uploaded avatar image -- same idea as
  /// [coverBytes].
  final Uint8List? avatarBytes;

  final String fallbackText;

  /// Announced by a screen reader when the cover has an image -- per the
  /// design spec's Accessibility note, only View Profile supplies this
  /// (Edit Profile deliberately doesn't add one, mirroring that the
  /// avatar picker never has one either).
  final String? coverSemanticsLabel;

  /// Non-null only in Edit Profile -- when set, the cover area becomes
  /// tappable and shows a camera badge. Null (the default) renders the
  /// same area read-only, per View Profile's usage.
  final VoidCallback? onTapCover;

  /// Same idea as [onTapCover], but for the avatar circle.
  final VoidCallback? onTapAvatar;

  static const _coverHeight = 140.0;
  static const _avatarRadius = 40.0;

  /// The white "separator ring" around the avatar adds 4px on every side,
  /// mirroring `ClubPage`'s own `CircleAvatar(radius: 32, ...)` wrapping a
  /// `radius: 28` icon (also a 4px ring).
  static const _avatarRingRadius = _avatarRadius + 4;

  Widget _cameraBadge(BuildContext context) => CircleAvatar(
        radius: 14,
        backgroundColor: Theme.of(context).colorScheme.surface,
        child: const Icon(Icons.camera_alt, size: 16),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editableCover = onTapCover != null;
    final editableAvatar = onTapAvatar != null;

    Widget cover = ClipRRect(
      borderRadius: BorderRadius.circular(WynSpacing.radiusMd),
      child: SizedBox(
        height: _coverHeight,
        width: double.infinity,
        child: coverBytes != null
            ? Image.memory(coverBytes!, fit: BoxFit.cover)
            : coverUrl != null
                ? Image.network(coverUrl!, fit: BoxFit.cover)
                : Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    // Only Edit Profile hints "tap to add a photo" here --
                    // View Profile's empty state is just a bare fill, same
                    // as Bio having no placeholder when unset.
                    child: editableCover
                        ? const Center(
                            child: Icon(Icons.add_photo_alternate_outlined, size: 32),
                          )
                        : null,
                  ),
      ),
    );

    if (coverSemanticsLabel != null && coverUrl != null) {
      cover = Semantics(
        label: coverSemanticsLabel,
        image: true,
        excludeSemantics: true,
        child: cover,
      );
    }

    Widget avatar = avatarBytes != null
        ? CircleAvatar(radius: _avatarRadius, backgroundImage: MemoryImage(avatarBytes!))
        : AvatarCircle(imageUrl: avatarUrl, fallbackText: fallbackText, radius: _avatarRadius);

    return SizedBox(
      height: _coverHeight + _avatarRingRadius,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            key: const Key('profile-cover-tap-target'),
            onTap: onTapCover,
            child: Stack(
              children: [
                cover,
                if (editableCover)
                  Positioned(right: 8, bottom: 8, child: _cameraBadge(context)),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: _coverHeight - _avatarRingRadius,
            child: Center(
              child: GestureDetector(
                key: const Key('profile-avatar-tap-target'),
                onTap: onTapAvatar,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: _avatarRingRadius,
                      backgroundColor: theme.colorScheme.surface,
                      child: avatar,
                    ),
                    if (editableAvatar)
                      Positioned(right: 0, bottom: 0, child: _cameraBadge(context)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
