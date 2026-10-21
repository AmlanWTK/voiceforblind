import 'package:flutter/material.dart';

import '../app/shuni_scope.dart';
import '../app/theme.dart';
import '../voice/prompts.dart';
import '../voice/voice_controller.dart';

/// The large round "কথা বলো" button. While Shuni is listening it turns
/// green, shows an ear icon and says "শুনছি"; tapping it then stops
/// listening.
class TalkButton extends StatelessWidget {
  const TalkButton({super.key, required this.onPressed, this.size = 196});

  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final voice = ShuniScope.of(context).voice;
    return ListenableBuilder(
      listenable: voice,
      builder: (context, _) {
        final listening = voice.phase == VoicePhase.listening;
        final color = listening ? ShuniColors.listening : ShuniColors.talk;
        final label = listening ? 'শুনছি…' : 'কথা বলো';
        return Semantics(
          button: true,
          label: listening ? 'শুনছি। থামাতে চাপো' : 'কথা বলো',
          hint: listening ? null : 'চাপ দিয়ে তোমার উত্তর বলো',
          onTap: onPressed,
          excludeSemantics: true,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(
                color: listening ? const Color(0xFFBBF7D0) : const Color(0xFFFED7AA),
                width: listening ? 12 : 6,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: listening ? 36 : 18,
                  spreadRadius: listening ? 8 : 2,
                ),
              ],
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onPressed,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      listening ? Icons.hearing : Icons.mic,
                      size: size * 0.36,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Shows in words and an icon what Shuni is doing: speaking, listening,
/// thinking or waiting for the child. Not a live region on purpose: an
/// automatic TalkBack announcement while the microphone is open would be
/// heard by the recogniser.
class VoiceStatusLine extends StatelessWidget {
  const VoiceStatusLine({super.key});

  @override
  Widget build(BuildContext context) {
    final voice = ShuniScope.of(context).voice;
    return ListenableBuilder(
      listenable: voice,
      builder: (context, _) {
        final (IconData icon, String text, Color color) = switch (voice.phase) {
          VoicePhase.speaking => (Icons.volume_up, 'আমি বলছি…', ShuniColors.primary),
          VoicePhase.listening => (Icons.hearing, 'শুনছি… এখন বলো', ShuniColors.listening),
          VoicePhase.thinking => (Icons.hourglass_top, 'ভাবছি…', ShuniColors.thinking),
          VoicePhase.idle => (Icons.touch_app, 'তোমার জন্য অপেক্ষা করছি', ShuniColors.inkSoft),
        };
        final heard = voice.lastHeard;
        return Semantics(
          container: true,
          label: heard == null ? text : '$text। শেষবার শুনেছি: $heard',
          excludeSemantics: true,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: ShuniColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: color, size: 30),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        text,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color),
                      ),
                    ),
                  ],
                ),
                if (heard != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'শুনেছি: “$heard”',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, color: ShuniColors.inkSoft),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A full-width, tall button with an icon, readable as one item by TalkBack.
class BigButton extends StatelessWidget {
  const BigButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.hint,
    this.outlined = false,
  });

  final IconData icon;
  final String label;
  final String? hint;
  final VoidCallback? onPressed;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 30),
        const SizedBox(width: 12),
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );
    final button = outlined
        ? OutlinedButton(onPressed: onPressed, child: child)
        : ElevatedButton(onPressed: onPressed, child: child);
    return MergeSemantics(
      child: Semantics(
        hint: hint,
        child: SizedBox(width: double.infinity, child: button),
      ),
    );
  }
}

/// Shown to adults if the phone has no Bangla text-to-speech voice.
class BanglaVoiceNotice extends StatelessWidget {
  const BanglaVoiceNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final voice = ShuniScope.of(context).voice;
    if (voice.banglaVoiceAvailable) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ShuniColors.notice,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text(
        'বড়দের জন্য: এই ফোনে বাংলা কণ্ঠ (Text-to-speech) পাওয়া যায়নি। '
        'সেটিংস → Text-to-speech → Google → ভাষা থেকে বাংলা ভয়েস ডাউনলোড করুন।',
        style: TextStyle(fontSize: 17, color: ShuniColors.ink),
      ),
    );
  }
}

/// Bangla back button for app bars (the default tooltip is English).
class ShuniBackButton extends StatelessWidget {
  const ShuniBackButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'ফিরে যাও',
      iconSize: 32,
      padding: const EdgeInsets.all(12),
      icon: const Icon(Icons.arrow_back),
      onPressed: onPressed,
    );
  }
}

/// Makes the whole screen a "talk" button: one tap anywhere that is not
/// itself a button starts listening (or stops it), so a blind child never
/// has to find the round button. Real buttons inside still work as usual.
///
/// Hidden from TalkBack: with TalkBack on, the labelled buttons are used.
class TapAnywhereToTalk extends StatelessWidget {
  const TapAnywhereToTalk({super.key, required this.onTalk, required this.child});

  final VoidCallback onTalk;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: onTalk,
      child: child,
    );
  }
}

/// Takes the child back to the start screen from anywhere, saying so first.
/// Returns false (and does nothing) if already on the start screen.
Future<bool> goHome(VoiceController voice, NavigatorState navigator) async {
  if (!navigator.canPop()) return false;
  final token = await voice.begin();
  await voice.say(token, Prompts.goingHome);
  navigator.popUntil((route) => route.isFirst);
  return true;
}

/// "শুরুর পাতা" button for app bars (for TalkBack users and sighted helpers;
/// children can also just say "হোম").
class ShuniHomeButton extends StatelessWidget {
  const ShuniHomeButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'শুরুর পাতা',
      iconSize: 32,
      padding: const EdgeInsets.all(12),
      icon: const Icon(Icons.home),
      onPressed: () => goHome(ShuniScope.of(context).voice, Navigator.of(context)),
    );
  }
}
