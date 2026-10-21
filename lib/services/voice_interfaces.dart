/// Interfaces between Shuni's screens and the device's speech/audio engines.
///
/// The real implementations wrap flutter_tts, speech_to_text and just_audio;
/// tests use fakes. Keeping them small makes the voice flow easy to follow.
library;

import '../voice/intent_parser.dart';

/// Text-to-speech in Bangla.
abstract class Speaker {
  /// Prepares the engine. Safe to call more than once.
  Future<void> init();

  /// False if the device has no Bangla voice; the app still tries to speak
  /// and shows a notice so an adult can install one.
  bool get banglaVoiceAvailable;

  /// Speaks [text] and completes when speaking has finished (or was stopped,
  /// or a safety timeout passed — it never waits forever).
  Future<void> speak(String text);

  Future<void> stop();
}

enum ListenStatus {
  /// Something was recognised; see [ListenResult.heard].
  heard,

  /// The child did not speak, or nothing could be matched.
  nothingHeard,

  /// Microphone permission is denied.
  permissionDenied,

  /// Speech recognition is not available on this device.
  unavailable,

  /// Recognition needs the internet and it failed.
  network,

  /// The recogniser does not support Bangla on this device.
  languageUnavailable,

  /// Any other recogniser failure.
  error,
}

class ListenResult {
  const ListenResult(this.status, {this.heard});
  final ListenStatus status;
  final Heard? heard;
}

/// One-shot speech recognition. The microphone is only on during [listenOnce].
abstract class SpeechInput {
  /// True if microphone permission is already granted (does not prompt).
  Future<bool> hasPermission();

  /// Initialises the recogniser; may show the system permission prompt.
  /// Returns null if ready, otherwise why it is not.
  Future<ListenStatus?> prepare();

  /// Listens for a single reply. Always completes, at the latest shortly
  /// after [listenFor].
  Future<ListenResult> listenOnce({
    Duration listenFor = const Duration(seconds: 8),
    Duration pauseFor = const Duration(seconds: 3),
  });

  /// Stops listening immediately and discards the result.
  Future<void> cancel();
}

/// Plays short recorded clips from the book (e.g. a narrator reading a title).
abstract class ClipPlayer {
  /// Plays [start]..[end] of [assetPath]. Returns false if the clip could
  /// not be played (missing file, decoder error). Completes when finished.
  Future<bool> playClip(String assetPath, Duration start, Duration end);

  Future<void> stop();

  Future<void> dispose();
}
