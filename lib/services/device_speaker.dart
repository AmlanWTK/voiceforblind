import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'voice_interfaces.dart';

/// Bangla text-to-speech using the device's TTS engine (Google TTS on most
/// Android phones). Tries bn-BD first, then bn-IN.
class DeviceSpeaker implements Speaker {
  DeviceSpeaker({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  bool _initialised = false;
  bool _banglaAvailable = false;
  bool _speaking = false;

  /// Bumped on every stop(), so a retry never revives a stopped sentence.
  int _stopGeneration = 0;

  /// Slightly slower and brighter than default: easier for young children.
  static const _speechRate = 0.42;
  static const _pitch = 1.08;
  static const _languages = ['bn-BD', 'bn-IN', 'bn'];

  @override
  bool get banglaVoiceAvailable => _banglaAvailable;

  @override
  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;
    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setSpeechRate(_speechRate);
      await _tts.setPitch(_pitch);
      await _tts.setVolume(1.0);
      // The Android engine binds asynchronously; give it a few tries.
      for (var attempt = 0; attempt < 3 && !_banglaAvailable; attempt++) {
        if (attempt > 0) await Future<void>.delayed(const Duration(milliseconds: 700));
        for (final lang in _languages) {
          final ok = await _tts.isLanguageAvailable(lang);
          if (ok == true) {
            await _tts.setLanguage(lang);
            _banglaAvailable = true;
            debugPrint('Shuni TTS: using $lang');
            break;
          }
        }
      }
      if (!_banglaAvailable) {
        // Still ask for Bangla: some engines under-report availability.
        await _tts.setLanguage('bn-BD');
        debugPrint('Shuni TTS: no Bangla voice reported by the engine');
      }
    } catch (e) {
      debugPrint('Shuni TTS init failed: $e');
    }
  }

  @override
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await init();
    // Generous upper bound so a stuck engine can never block the app.
    final limit = Duration(milliseconds: 4000 + text.length * 160);
    for (var attempt = 0; attempt < 2; attempt++) {
      final started = DateTime.now();
      final generation = _stopGeneration;
      _speaking = true;
      try {
        final result = await _tts.speak(text).timeout(limit, onTimeout: () async {
          await _tts.stop();
          return 1;
        });
        // The Android plugin returns 0 immediately (without speaking) when a
        // previous utterance has not finished stopping. Retry once.
        final instant = DateTime.now().difference(started) < const Duration(milliseconds: 120);
        if (result == 0 && instant && attempt == 0 && generation == _stopGeneration) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
          continue;
        }
      } catch (e) {
        debugPrint('Shuni TTS speak failed: $e');
      } finally {
        _speaking = false;
      }
      return;
    }
  }

  @override
  Future<void> stop() async {
    _stopGeneration++;
    final wasSpeaking = _speaking;
    try {
      await _tts.stop();
    } catch (_) {}
    if (wasSpeaking) {
      // Let the engine finish stopping before anything else is spoken.
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }
}
