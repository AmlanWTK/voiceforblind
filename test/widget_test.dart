// Drives Shuni's voice flow end to end with fake speech engines:
// app opens → greeting → child asks for a class → Class 1 books → book
// chosen → lesson chooser.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuni/app/shuni_app.dart';
import 'package:shuni/screens/book_screen.dart';
import 'package:shuni/screens/class_books_screen.dart';
import 'package:shuni/screens/home_screen.dart';
import 'package:shuni/services/voice_interfaces.dart';
import 'package:shuni/voice/prompts.dart';
import 'package:shuni/voice/voice_controller.dart';

import 'fakes.dart';

class Harness {
  Harness(List<ListenResult> script)
      : speaker = FakeSpeaker(),
        speech = FakeSpeechInput(script),
        clips = FakeClipPlayer() {
    voice = VoiceController(speaker: speaker, speech: speech, clips: clips);
  }

  final FakeSpeaker speaker;
  final FakeSpeechInput speech;
  final FakeClipPlayer clips;
  late final VoiceController voice;

  Widget get app => ShuniApp(
        voice: voice,
        repository: FakeLibraryRepository(testLibrary),
      );
}

/// Lets delayed starts, speech turns and page transitions run.
Future<void> settle(WidgetTester tester, {int steps = 12}) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  testWidgets('voice: Class 1 → Bangla book → lesson chooser', (tester) async {
    final t = Harness([
      FakeSpeechInput.said('ক্লাস ওয়ানের বই'),
      FakeSpeechInput.said('বাংলা বই পড়ব'),
    ]);
    await tester.pumpWidget(t.app);
    await settle(tester);

    // Greeting and question, then Class 1 confirmed.
    expect(t.speaker.spoken, containsAllInOrder([
      Prompts.greeting,
      Prompts.askClass,
      Prompts.classChosen(1),
    ]));
    expect(find.byType(ClassBooksScreen, skipOffstage: false), findsOneWidget);

    await settle(tester);
    // Books section announced and the title read in the narrator's voice.
    expect(t.speaker.spoken, contains(Prompts.classBooksWelcome(1)));
    expect(t.clips.played, contains('assets/test_book/aud003.mp3'));
    expect(t.speaker.spoken, contains(Prompts.bookChosen('বাংলা বই')));
    expect(find.byType(BookScreen), findsOneWidget);

    await settle(tester);
    expect(t.speaker.spoken, contains(Prompts.askLesson));
    expect(find.text('আমার পরিচয়'), findsOneWidget);

    // Nothing more scripted: Shuni retries once, then explains the buttons
    // and stops listening (no endless listening loop).
    await settle(tester, steps: 20);
    expect(t.speaker.spoken.last, Prompts.tapToTalk);
    final listensSoFar = t.speech.listens;
    await settle(tester, steps: 20);
    expect(t.speech.listens, listensSoFar);
  });

  testWidgets('English book: unit chooser → unit 2 → its lessons', (tester) async {
    final t = Harness([
      FakeSpeechInput.said('প্রথম শ্রেণির বই'),
      FakeSpeechInput.said('ইংরেজি বই'),
      FakeSpeechInput.said('দ্বিতীয় ইউনিট'),
    ]);
    await tester.pumpWidget(t.app);
    await settle(tester, steps: 30);

    expect(t.speaker.spoken, containsAllInOrder([
      Prompts.classChosen(1),
      Prompts.classBooksWelcome(1),
      Prompts.bookCount(2),
      Prompts.bookChosen('ইংরেজি বই'),
      '${Prompts.bookOpened} ${Prompts.unitCount(2)}',
      Prompts.askUnit,
      Prompts.unitChosen(2),
      Prompts.lessonCountInUnit(2),
      Prompts.askLesson,
    ]));
    // Both book titles were read in the narrators' voices.
    expect(t.clips.played, containsAll(['assets/test_book/aud003.mp3', 'assets/test_en/aud003.mp3']));
    // The unit's lessons are listed with their printed numbers.
    expect(find.text('The Alphabet Song'), findsOneWidget);
    expect(find.text('ইউনিট ২'), findsOneWidget);
  });

  testWidgets('saying "হোম" from a book goes back to the start screen', (tester) async {
    final t = Harness([
      FakeSpeechInput.said('ক্লাস ওয়ানের বই'),
      FakeSpeechInput.said('বাংলা বই পড়ব'),
      FakeSpeechInput.said('হোম'),
    ]);
    await tester.pumpWidget(t.app);
    await settle(tester, steps: 30);

    expect(t.speaker.spoken, containsAllInOrder([
      Prompts.bookChosen('বাংলা বই'),
      Prompts.askLesson,
      Prompts.goingHome,
      Prompts.askClassAgain,
    ]));
    expect(find.byType(BookScreen), findsNothing);
    expect(find.byType(ClassBooksScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('not understood: says the retry line, then offers buttons', (tester) async {
    final t = Harness([
      FakeSpeechInput.said('আকাশ নীল'),
      FakeSpeechInput.silence,
    ]);
    await tester.pumpWidget(t.app);
    await settle(tester, steps: 20);

    expect(t.speaker.spoken, containsAllInOrder([
      Prompts.askClass,
      Prompts.notUnderstoodClass,
      Prompts.tapToTalk,
    ]));
    expect(t.speech.listens, 2);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('bare number is confirmed before navigating', (tester) async {
    final t = Harness([
      FakeSpeechInput.said('এক'),
      FakeSpeechInput.said('হ্যাঁ'),
    ]);
    await tester.pumpWidget(t.app);
    await settle(tester);

    expect(t.speaker.spoken, containsAllInOrder([
      Prompts.confirmClass(1),
      Prompts.classChosen(1),
    ]));
    expect(find.byType(ClassBooksScreen), findsOneWidget);
  });

  testWidgets('a class without books offers Class 1', (tester) async {
    final t = Harness([
      FakeSpeechInput.said('ক্লাস টু'),
      FakeSpeechInput.said('হ্যাঁ'),
    ]);
    await tester.pumpWidget(t.app);
    await settle(tester);

    expect(t.speaker.spoken, contains(Prompts.classNotAvailable(2, 1)));
    expect(find.byType(ClassBooksScreen), findsOneWidget);
  });

  testWidgets('microphone denied: explains and points to the buttons', (tester) async {
    final t = Harness(const []);
    t.speech.permission = false;
    await tester.pumpWidget(t.app);
    await settle(tester);

    expect(t.speaker.spoken, containsAllInOrder([
      Prompts.askClass,
      Prompts.micPermissionComing,
      Prompts.micDenied,
    ]));
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('class button works without voice and is accessible', (tester) async {
    final handle = tester.ensureSemantics();
    final t = Harness(const []);
    await tester.pumpWidget(t.app);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.bySemanticsLabel('কথা বলো'), findsOneWidget);
    expect(find.text('আবার শোনো'), findsOneWidget);
    await tester.ensureVisible(find.text('প্রথম শ্রেণি'));
    await tester.pump();
    await tester.tap(find.text('প্রথম শ্রেণি'));
    await settle(tester);

    expect(t.speaker.spoken, contains(Prompts.classChosen(1)));
    expect(find.byType(ClassBooksScreen), findsOneWidget);
    await settle(tester, steps: 30);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}
