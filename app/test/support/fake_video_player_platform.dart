import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// A fake VideoPlayerPlatform so widget tests can exercise
/// VideoPlayerController.initialize() deterministically, instead of it
/// failing with a MissingPluginException (no real platform channel
/// handler exists in the test environment). Without this, anything
/// gated behind a successful video initialization -- view recording,
/// mute/volume propagation -- would be untestable, the same class of gap
/// Image.network leaves for Drop (accepted there because nothing in Drop
/// depends on the image actually loading; here things do).
///
/// Install once via `VideoPlayerPlatform.instance = FakeVideoPlayerPlatform()`
/// before pumping any widget that creates a VideoPlayerController.
class FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  int _nextPlayerId = 0;
  final Map<int, StreamController<VideoEvent>> _eventControllers = {};

  final List<double> setVolumeCalls = [];
  final List<bool> playCalls = [];
  final List<bool> pauseCalls = [];
  int disposeCalls = 0;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final playerId = _nextPlayerId++;
    _eventControllers[playerId] = StreamController<VideoEvent>.broadcast();
    return playerId;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    final controller = _eventControllers[playerId]!;
    // Emitted after returning, so it lands after initialize()'s
    // synchronous .listen() call attaches -- see video_player's
    // VideoPlayerController.initialize().
    Future(() {
      if (controller.isClosed) return;
      controller.add(VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 15),
        size: const Size(1080, 1920),
      ));
    });
    return controller.stream;
  }

  @override
  Future<void> dispose(int playerId) async {
    disposeCalls++;
    await _eventControllers.remove(playerId)?.close();
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> play(int playerId) async {
    playCalls.add(true);
  }

  @override
  Future<void> pause(int playerId) async {
    pauseCalls.add(true);
  }

  @override
  Future<void> setVolume(int playerId, double volume) async {
    setVolumeCalls.add(volume);
  }

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const SizedBox.shrink();

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
}
