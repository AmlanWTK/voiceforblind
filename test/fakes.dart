import 'package:shuni/content/library_repository.dart';
import 'package:shuni/content/models.dart';
import 'package:shuni/services/voice_interfaces.dart';
import 'package:shuni/voice/intent_parser.dart';

/// Records everything Shuni says instead of speaking.
class FakeSpeaker implements Speaker {
  final spoken = <String>[];

  @override
  bool banglaVoiceAvailable = true;

  @override
  Future<void> init() async {}

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stop() async {}
}

/// Answers each listening turn from a script.
class FakeSpeechInput implements SpeechInput {
  FakeSpeechInput(List<ListenResult> script) : _script = [...script];

  final List<ListenResult> _script;
  int listens = 0;
  bool permission = true;

  static ListenResult said(String text) =>
      ListenResult(ListenStatus.heard, heard: Heard([text]));
  static const silence = ListenResult(ListenStatus.nothingHeard);

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<ListenStatus?> prepare() async =>
      permission ? null : ListenStatus.permissionDenied;

  @override
  Future<ListenResult> listenOnce({
    Duration listenFor = const Duration(seconds: 8),
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    listens++;
    if (!permission) return const ListenResult(ListenStatus.permissionDenied);
    return _script.isEmpty ? silence : _script.removeAt(0);
  }

  @override
  Future<void> cancel() async {}
}

class FakeClipPlayer implements ClipPlayer {
  final played = <String>[];

  @override
  Future<bool> playClip(String assetPath, Duration start, Duration end) async {
    played.add(assetPath);
    return true;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

class FakeLibraryRepository extends LibraryRepository {
  FakeLibraryRepository(this.library);
  final Library library;

  @override
  Future<Library> load() async => library;
}

Section _lesson(int n, String title, {int? unit, int? inUnit}) => Section(
      id: 'ncx_${unit ?? 0}_$n',
      kind: SectionKind.lesson,
      number: n,
      unit: unit,
      lessonInUnit: inUnit,
      title: title,
      fullTitle: 'পাঠ $n - $title',
      audioFiles: ['aud${n + 5}.mp3'],
      duration: const Duration(seconds: 20),
      pages: const ['২'],
      titleClip: AudioClip(
        audio: 'aud${n + 5}.mp3',
        start: Duration.zero,
        end: const Duration(seconds: 4),
      ),
      segments: [
        Segment(
          audio: 'aud${n + 5}.mp3',
          start: Duration.zero,
          end: const Duration(seconds: 4),
          kind: SegmentKind.heading,
          text: 'পাঠ $n - $title',
        ),
      ],
    );

/// A small library shaped like the real one (Class 1, আমার বাংলা বই).
final testLibrary = Library(classes: [
  SchoolClass(id: 1, nameBn: 'প্রথম শ্রেণি', books: [
    Book(
      id: 'amar_bangla_boi_class1',
      classId: 1,
      title: 'আমার বাংলা বই - প্রথম শ্রেণি',
      shortTitle: 'আমার বাংলা বই',
      subject: 'bangla',
      subjectNameBn: 'বাংলা',
      spokenNames: const ['বাংলা', 'বাংলা বই', 'আমার বাংলা বই', 'bangla'],
      basePath: 'assets/test_book/',
      cover: null,
      titleClip: const AudioClip(
        audio: 'aud003.mp3',
        start: Duration.zero,
        end: Duration(seconds: 3),
      ),
      sections: [
        _lesson(1, 'আমার পরিচয়'),
        _lesson(2, 'এসো রং করি ও আঁকি'),
        _lesson(9, 'বাঘ ও রাখাল'),
      ],
    ),
    Book(
      id: 'english_for_today_class1',
      classId: 1,
      title: 'English For Today - Class One',
      shortTitle: 'English For Today',
      subject: 'english',
      subjectNameBn: 'ইংরেজি',
      spokenNames: const ['ইংরেজি', 'ইংরেজি বই', 'ইংলিশ', 'english'],
      basePath: 'assets/test_en/',
      cover: null,
      titleClip: const AudioClip(
        audio: 'aud003.mp3',
        start: Duration.zero,
        end: Duration(seconds: 3),
      ),
      units: const [
        Unit(number: 1, title: 'Greetings and Farewells', fullTitle: 'Unit - 1 Greetings and Farewells', titleClip: null),
        Unit(number: 2, title: 'The Alphabet and Numbers', fullTitle: 'Unit – 2- The Alphabet and Numbers', titleClip: null),
      ],
      sections: [
        _lesson(1, 'Good Morning (1)', unit: 1, inUnit: 1),
        _lesson(2, 'Good Morning (2)', unit: 1, inUnit: 2),
        _lesson(3, 'The Alphabet Song', unit: 2, inUnit: 1),
        _lesson(4, 'aA bB', unit: 2, inUnit: 2),
      ],
    ),
  ]),
]);
