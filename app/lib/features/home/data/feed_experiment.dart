import 'feed_source.dart';

/// Typed, client-safe subset of a server-resolved experiment configuration.
/// Assignment, eligibility, conflict handling and exposure recording stay in
/// PostgreSQL; malformed/missing payloads always resolve to production values.
class EffectiveHomeExperiment {
  const EffectiveHomeExperiment({
    this.sourceWeights,
    this.fatigue = FeedFatigueConfig.production,
    this.assignments = const [],
  });

  const EffectiveHomeExperiment.production()
      : sourceWeights = null,
        fatigue = FeedFatigueConfig.production,
        assignments = const [];

  final Map<FeedSource, int>? sourceWeights;
  final FeedFatigueConfig fatigue;
  final List<String> assignments;

  factory EffectiveHomeExperiment.fromRpc(Object? value) {
    try {
      if (value is! Map) return const EffectiveHomeExperiment.production();
      final map = Map<String, dynamic>.from(value);
      Map<FeedSource, int>? weights;
      final rawMix = map['home.source_mix'];
      if (rawMix is Map) {
        final candidate = <FeedSource, int>{};
        for (final source in FeedSource.values) {
          final raw = rawMix[source.wireName];
          if (raw is! num || raw < 0 || raw > 100 || raw != raw.round()) {
            return const EffectiveHomeExperiment.production();
          }
          candidate[source] = raw.toInt();
        }
        if (candidate.values.fold<int>(0, (sum, value) => sum + value) !=
            100) {
          return const EffectiveHomeExperiment.production();
        }
        weights = Map.unmodifiable(candidate);
      }
      double boundedFactor(String key, double production) {
        final raw = map[key];
        if (raw == null) return production;
        if (raw is! num || !raw.isFinite || raw < 0.1 || raw > 1.0) {
          throw const FormatException('Invalid experiment factor');
        }
        return raw.toDouble();
      }

      return EffectiveHomeExperiment(
        sourceWeights: weights,
        fatigue: FeedFatigueConfig(
          creatorFactor: boundedFactor('fatigue.creator_factor', 0.82),
          topicFactor: boundedFactor('fatigue.topic_factor', 0.88),
          contentTypeFactor:
              boundedFactor('fatigue.content_type_factor', 0.94),
          repetitionFactor:
              boundedFactor('fatigue.repetition_factor', 0.35),
        ),
        assignments: (map['_assignments'] as List?)
                ?.whereType<String>()
                .take(8)
                .toList(growable: false) ??
            const [],
      );
    } catch (_) {
      return const EffectiveHomeExperiment.production();
    }
  }
}

class FeedFatigueConfig {
  const FeedFatigueConfig({
    required this.creatorFactor,
    required this.topicFactor,
    required this.contentTypeFactor,
    required this.repetitionFactor,
  });

  static const production = FeedFatigueConfig(
    creatorFactor: 0.82,
    topicFactor: 0.88,
    contentTypeFactor: 0.94,
    repetitionFactor: 0.35,
  );

  final double creatorFactor;
  final double topicFactor;
  final double contentTypeFactor;
  final double repetitionFactor;
}
