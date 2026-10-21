import 'package:flutter/foundation.dart';

import '../content/models.dart';
import '../services/voice_interfaces.dart';
import 'intent_parser.dart';
import 'prompts.dart';

/// What Shuni is doing right now; shown on screen in words and icons.
enum VoicePhase { idle, speaking, listening, thinking }

/// Runs Shuni's voice conversations: speaking, playing recorded clips and
/// listening, one step at a time.
///
/// Every conversation starts with [begin], which stops whatever was going on
/// and returns a token. Each step takes that token and returns false/null
/// once the conversation has been superseded (the child tapped something,
/// or the screen changed), so old flows quietly stop instead of talking over
/// new ones.
class VoiceController extends ChangeNotifier {
  VoiceController({
    required this.speaker,
    required this.speech,
    required this.clips,
  });

  final Speaker speaker;
  final SpeechInput speech;
  final ClipPlayer clips;

  VoicePhase _phase = VoicePhase.idle;
  VoicePhase get phase => _phase;

  /// The last thing the child was heard saying (shown on screen for adults).
  String? _lastHeard;
  String? get lastHeard => _lastHeard;

  /// Set when listening failed for a reason the child cannot fix by talking.
  ListenStatus? _blockedReason;
  ListenStatus? get blockedReason => _blockedReason;

  int _generation = 0;
  bool _disposed = false;

  /// Takes the child to the start screen. Set by the app; returns false if
  /// already there (then "হোম" is treated like any other answer).
  Future<bool> Function()? homeHandler;

  /// True once the full list of lesson commands has been spoken in this
  /// app session; later lessons get the short reminder.
  bool playerGuideHeard = false;

  Future<void> init() => speaker.init();

  bool get banglaVoiceAvailable => speaker.banglaVoiceAvailable;

  /// Starts a new conversation, stopping any current one.
  Future<int> begin() async {
    final token = ++_generation;
    await _stopEngines();
    _setPhase(VoicePhase.idle);
    return token;
  }

  bool isActive(int token) => !_disposed && token == _generation;

  /// Stops everything (e.g. when a screen goes away).
  Future<void> interrupt() async {
    _generation++;
    await _stopEngines();
    _setPhase(VoicePhase.idle);
  }

  /// Speaks [text]. Returns false if the conversation was superseded.
  Future<bool> say(int token, String text) async {
    if (!isActive(token)) return false;
    _setPhase(VoicePhase.speaking);
    await speaker.speak(text);
    if (!isActive(token)) return false;
    _setPhase(VoicePhase.idle);
    return true;
  }

  /// Plays a recorded clip from [book]; falls back to speaking
  /// [fallbackText] if the clip is missing or cannot be played.
  Future<bool> playClipOrSay(
    int token,
    Book book,
    AudioClip? clip,
    String fallbackText,
  ) async {
    if (!isActive(token)) return false;
    var played = false;
    if (clip != null) {
      _setPhase(VoicePhase.speaking);
      played = await clips.playClip(book.assetPath(clip.audio), clip.start, clip.end);
      if (!isActive(token)) return false;
    }
    if (!played) return say(token, fallbackText);
    _setPhase(VoicePhase.idle);
    return true;
  }

  /// Listens once. Returns null if the conversation was superseded.
  Future<ListenResult?> listen(
    int token, {
    Duration listenFor = const Duration(seconds: 8),
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    if (!isActive(token)) return null;
    _setPhase(VoicePhase.listening);
    final result = await speech.listenOnce(listenFor: listenFor, pauseFor: pauseFor);
    if (!isActive(token)) return null;
    _lastHeard = result.heard?.best;
    _blockedReason = switch (result.status) {
      ListenStatus.permissionDenied ||
      ListenStatus.unavailable ||
      ListenStatus.languageUnavailable =>
        result.status,
      _ => null,
    };
    _setPhase(VoicePhase.thinking);
    return result;
  }

  bool _permissionExplained = false;

  /// Asks a question and listens for an answer that [understand] can make
  /// sense of, retrying with [retryPrompt] once ([attempts] in total).
  ///
  /// Returns the understood answer, or null if the conversation was
  /// superseded or the child could not be understood. In the second case
  /// the child has already been told what to do instead (tap the big
  /// button, use the buttons below, …).
  Future<T?> ask<T>(
    int token, {
    required String prompt,
    required String retryPrompt,
    required T? Function(Heard heard) understand,
    int attempts = 2,
  }) async {
    var text = prompt;
    for (var i = 0; i < attempts; i++) {
      if (!await say(token, text)) return null;
      if (!_permissionExplained && !await speech.hasPermission()) {
        _permissionExplained = true;
        if (!await say(token, Prompts.micPermissionComing)) return null;
      }
      final result = await listen(token);
      if (result == null) return null;
      switch (result.status) {
        case ListenStatus.heard:
          // "হোম" works on every screen, whatever was asked.
          final handler = homeHandler;
          if (handler != null && isHomeRequest(result.heard!) && await handler()) {
            return null;
          }
          final value = understand(result.heard!);
          if (value != null) return value;
        case ListenStatus.nothingHeard:
        case ListenStatus.error:
          break;
        case ListenStatus.permissionDenied:
        case ListenStatus.unavailable:
        case ListenStatus.network:
        case ListenStatus.languageUnavailable:
          await say(token, messageFor(result.status));
          settle(token);
          return null;
      }
      text = retryPrompt;
    }
    await say(token, Prompts.tapToTalk);
    settle(token);
    return null;
  }

  /// What to tell the child when listening is impossible.
  static String messageFor(ListenStatus status) => switch (status) {
        ListenStatus.permissionDenied => Prompts.micDenied,
        ListenStatus.unavailable => Prompts.speechUnavailable,
        ListenStatus.network => Prompts.speechNetwork,
        ListenStatus.languageUnavailable => Prompts.speechNoBangla,
        _ => Prompts.speechError,
      };

  /// Marks the end of a conversation step: nothing is happening now and
  /// the app is waiting for the child.
  void settle(int token) {
    if (isActive(token)) _setPhase(VoicePhase.idle);
  }

  Future<bool> hasMicPermission() => speech.hasPermission();

  Future<void> _stopEngines() async {
    await speech.cancel();
    await clips.stop();
    await speaker.stop();
  }

  void _setPhase(VoicePhase p) {
    if (_disposed || _phase == p) return;
    _phase = p;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    speaker.stop();
    speech.cancel();
    clips.dispose();
    super.dispose();
  }
}
