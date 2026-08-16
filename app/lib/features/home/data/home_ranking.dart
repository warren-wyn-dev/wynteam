import 'home_feed_item.dart';

/// Weighted score for Home's ranked "สำหรับคุณ" feed -- WYN-018. Every
/// term is plain arithmetic over data already on the item plus one
/// extra fact (does the viewer follow this author), so the result can
/// always be recomputed by hand -- deliberately not a black-box model.
/// See .wyn/docs/design/wyn-018-home-feed-ranking.md for the reasoning
/// behind each weight.
double rankingScore(
  HomeFeedItem item, {
  required DateTime now,
  required bool isFollowingAuthor,
}) {
  final hoursSincePosted = now.difference(item.createdAt).inMinutes / 60.0;
  final recencyScore = (168 - hoursSincePosted).clamp(0.0, 168.0);
  final engagementScore = item.likeCount * 2 + item.commentCount * 3;
  final followingBoost = isFollowingAuthor ? 50 : 0;

  return recencyScore + engagementScore + followingBoost;
}
