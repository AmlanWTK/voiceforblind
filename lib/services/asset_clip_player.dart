import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'voice_interfaces.dart';

/// Plays a time range of a bundled MP3 — used for the narrator's own
/// recordings of book and lesson titles.
class AssetClipPlayer implements ClipPlayer {
  AssetClipPlayer() : _player = AudioPlayer();

  final AudioPlayer _player;
  Completer<void>? _stopped;

  @override
  Future<bool> playClip(String assetPath, Duration start, Duration end) async {
    await stop();
    final stopped = _stopped = Completer<void>();
    try {
      await _player.setAudioSource(ClippingAudioSource(
        child: AudioSource.asset(assetPath),
        start: start,
        end: end,
      ));
      final completed = _player.processingStateStream
          .firstWhere((s) => s == ProcessingState.completed);
      unawaited(_player.play().catchError((Object e) {
        debugPrint('Shuni: clip playback failed: $e');
      }));
      final limit = (end - start) + const Duration(seconds: 3);
      await Future.any<void>([
        // Errors here (e.g. player disposed) just end the clip.
        completed.then<void>((_) {}, onError: (Object _) {}),
        stopped.future,
      ]).timeout(limit, onTimeout: () {});
      await _player.pause();
      return true;
    } catch (e) {
      debugPrint('Shuni: could not play clip $assetPath: $e');
      return false;
    } finally {
      if (!stopped.isCompleted) stopped.complete();
    }
  }

  @override
  Future<void> stop() async {
    final s = _stopped;
    if (s != null && !s.isCompleted) s.complete();
    try {
      await _player.stop();
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _player.dispose();
  }
}
