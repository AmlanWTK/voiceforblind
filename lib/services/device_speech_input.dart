import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../voice/intent_parser.dart';
import 'voice_interfaces.dart';

/// One-shot Bangla speech recognition with the device's recogniser
/// (Android SpeechRecognizer). The microphone is only open inside
/// [listenOnce]; there is no continuous listening.
class DeviceSpeechInput implements SpeechInput {
  DeviceSpeechInput({SpeechToText? stt}) : _stt = stt ?? SpeechToText();

  final SpeechToText _stt;
  bool _ready = false;
  String _localeId = 'bn-BD';

  Completer<ListenResult>? _pending;
  List<String> _latest = const [];
  bool _lowConfidence = false;
  Timer? _safetyTimer;

  /// Increases with every listen, so late events from an old session are ignored.
  int _session = 0;

  @override
  Future<bool> hasPermission() async {
    try {
      return await _stt.hasPermission;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<ListenStatus?> prepare() async {
    if (_ready) return null;
    try {
      final ok = await _stt.initialize(
        onError: _onError,
        onStatus: _onStatus,
        finalTimeout: const Duration(milliseconds: 1500),
      );
      if (!ok) {
        return await hasPermission()
            ? ListenStatus.unavailable
            : ListenStatus.permissionDenied;
      }
      _ready = true;
      _localeId = await _pickBanglaLocale();
      debugPrint('Shuni STT: locale $_localeId');
      return null;
    } catch (e) {
      debugPrint('Shuni STT init failed: $e');
      return ListenStatus.unavailable;
    }
  }

  Future<String> _pickBanglaLocale() async {
    try {
      final locales = await _stt.locales().timeout(const Duration(seconds: 3));
      String? find(String prefix) {
        for (final l in locales) {
          final id = l.localeId.toLowerCase().replaceAll('-', '_');
          if (id.startsWith(prefix)) return l.localeId;
        }
        return null;
      }

      return find('bn_bd') ?? find('bn_in') ?? find('bn') ?? 'bn-BD';
    } catch (_) {
      // Many Android recognisers support Bangla without listing it.
      return 'bn-BD';
    }
  }

  @override
  Future<ListenResult> listenOnce({
    Duration listenFor = const Duration(seconds: 8),
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    final notReady = await prepare();
    if (notReady != null) return ListenResult(notReady);
    if (_pending != null || _stt.isListening) await cancel();

    _safetyTimer?.cancel();
    final completer = Completer<ListenResult>();
    _pending = completer;
    _session++;
    _latest = const [];
    _lowConfidence = false;

    // Never leave the child waiting: force an answer shortly after the
    // listening window even if the recogniser goes quiet.
    _safetyTimer = Timer(listenFor + const Duration(seconds: 4), () async {
      try {
        await _stt.stop();
      } catch (_) {}
      _finishWithLatest();
    });

    try {
      await _stt.listen(
        onResult: _onResult,
        listenOptions: SpeechListenOptions(
          listenFor: listenFor,
          pauseFor: pauseFor,
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.confirmation,
          localeId: _localeId,
        ),
      );
    } catch (e) {
      debugPrint('Shuni STT listen failed: $e');
      _finish(const ListenResult(ListenStatus.error));
    }
    return completer.future;
  }

  @override
  Future<void> cancel() async {
    _safetyTimer?.cancel();
    if (_ready) {
      try {
        await _stt.cancel();
      } catch (_) {}
    }
    _finish(const ListenResult(ListenStatus.nothingHeard));
  }

  void _onResult(SpeechRecognitionResult result) {
    final words = [
      for (final a in result.alternates)
        if (a.recognizedWords.trim().isNotEmpty) a.recognizedWords,
    ];
    if (words.isNotEmpty) _latest = words;
    if (result.hasConfidenceRating && result.confidence < 0.5) {
      _lowConfidence = true;
    }
    if (result.finalResult) _finishWithLatest();
  }

  void _onStatus(String status) {
    if (status == SpeechToText.doneStatus) {
      // Give a final result a moment to arrive before deciding. If a new
      // session is already listening, this "done" belonged to an old one.
      final session = _session;
      Timer(const Duration(milliseconds: 400), () {
        if (session == _session && !_stt.isListening) _finishWithLatest();
      });
    }
  }

  void _onError(SpeechRecognitionError error) {
    debugPrint('Shuni STT error: ${error.errorMsg} permanent=${error.permanent}');
    if (_latest.isNotEmpty) {
      _finishWithLatest();
      return;
    }
    _finish(ListenResult(_statusFor(error.errorMsg)));
  }

  static ListenStatus _statusFor(String msg) {
    if (msg.contains('permission')) return ListenStatus.permissionDenied;
    if (msg.contains('no_match') || msg.contains('speech_timeout')) {
      return ListenStatus.nothingHeard;
    }
    if (msg.contains('language')) return ListenStatus.languageUnavailable;
    if (msg.contains('network') || msg.contains('server')) return ListenStatus.network;
    return ListenStatus.error;
  }

  void _finishWithLatest() {
    if (_latest.isEmpty) {
      _finish(const ListenResult(ListenStatus.nothingHeard));
    } else {
      _finish(ListenResult(
        ListenStatus.heard,
        heard: Heard(_latest, lowConfidence: _lowConfidence),
      ));
    }
  }

  void _finish(ListenResult result) {
    final c = _pending;
    if (c == null || c.isCompleted) return;
    _pending = null;
    _safetyTimer?.cancel();
    c.complete(result);
  }
}
