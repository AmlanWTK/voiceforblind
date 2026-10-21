import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../content/models.dart';
import '../voice/bangla_text.dart';
import '../voice/intent_parser.dart';
import '../voice/prompts.dart';
import '../voice/voice_controller.dart';
import '../widgets/voice_screen.dart';
import '../widgets/voice_widgets.dart';
import 'class_books_screen.dart';

/// First screen. Greets the child, asks which class's books they want and
/// listens for the answer. Big buttons below are the fallback when voice
/// does not work.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with VoiceScreenMixin<HomeScreen> {
  @override
  Future<void> onVoiceStart({required bool first}) async {
    final token = await voice.begin();
    if (library.availableClasses.isEmpty) {
      await voice.say(token, Prompts.noLibrary);
      voice.settle(token);
      return;
    }
    if (first && !await voice.say(token, Prompts.greeting)) return;
    await _askForClass(token, first ? Prompts.askClass : Prompts.askClassAgain);
  }

  /// Big button: the child wants to speak now.
  Future<void> _onTalk() async {
    if (voice.phase == VoicePhase.listening) {
      await voice.interrupt();
      return;
    }
    final token = await voice.begin();
    await _askForClass(token, Prompts.askClassAgain);
  }

  /// "আবার শোনো": repeat the instruction in full.
  Future<void> _onRepeat() async {
    final token = await voice.begin();
    await _askForClass(token, Prompts.askClass);
  }

  Future<void> _askForClass(int token, String prompt) async {
    if (library.availableClasses.isEmpty) {
      await voice.say(token, Prompts.noLibrary);
      voice.settle(token);
      return;
    }
    final reply = await voice.ask<ClassReply>(
      token,
      prompt: prompt,
      retryPrompt: Prompts.notUnderstoodClass,
      understand: (heard) {
        final r = parseClassReply(heard);
        return r.kind == ClassReplyKind.unknown ? null : r;
      },
    );
    if (reply == null || !mounted) return;

    if (reply.kind == ClassReplyKind.repeat) {
      await _askForClass(token, Prompts.askClass);
      return;
    }

    final n = reply.classNumber!;
    final wanted = library.classById(n);
    if (wanted != null) {
      if (reply.needsConfirmation) {
        final answer = await _confirm(token, Prompts.confirmClass(n), expectedClass: n);
        if (answer == null || !mounted) return;
        if (answer == YesNo.no) {
          if (await voice.say(token, Prompts.okWaiting)) {
            await _askForClass(token, Prompts.askClassAgain);
          }
          return;
        }
      }
      await _openClass(token, wanted);
      return;
    }

    // Asked for a class whose books are not in the app yet.
    final offered = library.availableClasses.first;
    final answer = await _confirm(
      token,
      Prompts.classNotAvailable(n, offered.id),
      expectedClass: offered.id,
    );
    if (answer == null || !mounted) return;
    if (answer == YesNo.yes) {
      await _openClass(token, offered);
    } else if (await voice.say(token, Prompts.okWaiting)) {
      await _askForClass(token, Prompts.askClassAgain);
    }
  }

  /// Yes/no question. Saying the expected class again also counts as yes.
  Future<YesNo?> _confirm(int token, String question, {required int expectedClass}) {
    return voice.ask<YesNo>(
      token,
      prompt: question,
      retryPrompt: Prompts.yesOrNo,
      understand: (heard) {
        // A class named with "ক্লাস"/"শ্রেণি"/"বই" decides it, so
        // "দ্বিতীয় শ্রেণির বই চাই" is not taken as yes to Class 1.
        final c = parseClassReply(heard);
        if (c.kind == ClassReplyKind.classNumber && !c.needsConfirmation) {
          return c.classNumber == expectedClass ? YesNo.yes : YesNo.no;
        }
        final yn = parseYesNo(heard);
        if (yn != YesNo.unknown) return yn;
        if (c.kind == ClassReplyKind.classNumber) {
          return c.classNumber == expectedClass ? YesNo.yes : YesNo.no;
        }
        return null;
      },
    );
  }

  Future<void> _openClass(int token, SchoolClass cls) async {
    if (!await voice.say(token, Prompts.classChosen(cls.id))) return;
    voice.settle(token);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ClassBooksScreen(schoolClass: cls),
    ));
  }

  Future<void> _onClassButton(SchoolClass cls) async {
    final token = await voice.begin();
    await _openClass(token, cls);
  }

  @override
  Widget build(BuildContext context) {
    final classes = library.availableClasses;
    return Scaffold(
      body: TapAnywhereToTalk(
        onTalk: _onTalk,
        child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const BanglaVoiceNotice(),
              Semantics(
                header: true,
                child: Text(
                  'শুনি',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'শুনে শুনে পড়ি',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, color: ShuniColors.inkSoft),
              ),
              const SizedBox(height: 20),
              const VoiceStatusLine(),
              const SizedBox(height: 28),
              Center(child: TalkButton(onPressed: _onTalk)),
              const SizedBox(height: 28),
              BigButton(
                icon: Icons.replay,
                label: 'আবার শোনো',
                hint: 'প্রশ্নটি আবার শুনতে চাপো',
                outlined: true,
                onPressed: _onRepeat,
              ),
              const SizedBox(height: 32),
              Semantics(
                header: true,
                child: Text(
                  'অথবা শ্রেণি বেছে নাও',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 12),
              if (classes.isEmpty)
                const Text('কোনো বই পাওয়া যায়নি।', style: TextStyle(fontSize: 20))
              else
                for (final c in classes) ...[
                  BigButton(
                    icon: Icons.menu_book,
                    label: classNameBn(c.id),
                    hint: '${classNameBn(c.id)}র বই খুলতে চাপো',
                    onPressed: () => _onClassButton(c),
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        ),
      ),
      ),
    );
  }
}
