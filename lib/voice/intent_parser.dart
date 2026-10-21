/// Turns what the speech recogniser heard into a decision for each screen.
///
/// Pure Dart with no Flutter or plugin dependencies, so it is fully covered by
/// unit tests (test/intent_parser_test.dart). Every check runs over all the
/// alternatives the recogniser offers, best first.
library;

import '../content/models.dart';
import 'bangla_text.dart';

/// What the recogniser returned for one listening turn.
class Heard {
  Heard(List<String> alternatives, {this.lowConfidence = false})
      : alternatives = [
          for (final a in alternatives)
            if (a.trim().isNotEmpty) a.trim(),
        ],
        normalized = [
          for (final a in alternatives)
            if (normalizeSpeech(a).isNotEmpty) normalizeSpeech(a),
        ];

  /// Raw text, best guess first.
  final List<String> alternatives;

  /// [alternatives] after [normalizeSpeech].
  final List<String> normalized;

  /// True when the recogniser reported a low confidence score.
  final bool lowConfidence;

  bool get isEmpty => normalized.isEmpty;
  String get best => alternatives.isEmpty ? '' : alternatives.first;
}

// ---------------------------------------------------------------------------
// Word lists (any spelling; they are normalised before comparison)
// ---------------------------------------------------------------------------

const classWords = [
  'ক্লাস', 'ক্লাশ', 'ক্লাসের', 'শ্রেণি', 'শ্রেণী', 'class', 'klass', 'clas',
  'shreni', 'sreni', 'shroni',
];
const bookWords = ['বই', 'বইটা', 'বইগুলো', 'boi', 'book', 'books'];
const repeatWords = [
  'আবার', 'আরেকবার', 'repeat', 'again', 'abar', 'বুঝিনি', 'কী বললে', 'কি বললে',
];
const backWords = [
  'ফিরে', 'ফেরত', 'পেছনে', 'পিছনে', 'পিছে', 'back', 'firo', 'fire jao',
];
const listWords = [
  'সূচি', 'সূচিপত্র', 'সুচি', 'তালিকা', 'লিস্ট', 'list', 'index', 'menu',
  'সব পাঠ', 'পাঠগুলো', 'পাঠের নাম', 'নামগুলো',
];
const moreWords = ['আরও', 'আরো', 'বাকি', 'more', 'aro', 'baki'];
const nextWords = ['পরের', 'পরেরটা', 'পরবর্তী', 'সামনের', 'next', 'porer'];
const previousWords = ['আগের', 'আগেরটা', 'পূর্বের', 'previous', 'prev', 'ager'];
const sentenceWords = ['লাইন', 'বাক্য', 'লাইনে', 'line', 'sentence', 'kotha'];
const lessonWords = ['পাঠ', 'লেসন', 'লেসসন', 'lesson', 'chapter', 'path'];
const unitWords = ['ইউনিট', 'ইউনিড', 'ইউনিত', 'unit', 'unite'];
const _numberFillers = ['নম্বর', 'নাম্বার', 'নং', 'number', 'no'];
const pauseWords = [
  'থামো', 'থামাও', 'থাম', 'থামুন', 'থামাও তো', 'বন্ধ', 'দাঁড়াও', 'pause', 'stop',
  'wait', 'thamo',
];
const playWords = [
  'চালাও', 'চালু', 'শুরু', 'চলো', 'শোনাও', 'শুনাও', 'পড়ো', 'পড়', 'play', 'start',
  'continue', 'resume', 'chalao', 'shuru',
];
/// Go back to the first screen from anywhere.
const homeWords = [
  'হোম', 'home', 'homepage', 'হোমপেজ', 'হোম পেজ', 'হোম পেইজ', 'মেইন পেজ', 'main page',
  'শুরুর পাতা', 'শুরুর পাতায়', 'প্রথম পাতা', 'প্রথম পাতায়', 'মূল পাতা', 'মূল পাতায়',
  'প্রধান পাতা', 'প্রধান পাতায়',
];

/// True if the child asked to go to the start screen ("হোম", "হোমে যাও",
/// "শুরুর পাতায় যাও").
bool isHomeRequest(Heard heard) =>
    heard.normalized.any((alt) => mentionsAny(alt, homeWords));

const helpWords = [
  'সাহায্য', 'সাহায্য করো', 'help', 'নিয়ম', 'কী বলব', 'কি বলব', 'কী বলতে পারি',
  'কি বলতে পারি', 'কী বলতে হবে', 'কি বলতে হবে', 'shahajjo',
];
const restartWords = ['আবার', 'আরেকবার', 'প্রথম থেকে', 'শুরু থেকে', 'repeat', 'again', 'abar'];

const _yesWords = [
  'হ্যাঁ', 'হ্যা', 'হাঁ', 'হা', 'হুম', 'হু', 'জি', 'জ্বি', 'জী', 'ঠিক', 'আচ্ছা', 'চাই',
  'ওকে', 'অবশ্যই', 'yes', 'yeah', 'yep', 'yup', 'ok', 'okay', 'ha', 'hya', 'hyan',
  'haan', 'ji', 'thik',
];
const _noWords = ['না', 'নাহ', 'নো', 'নয়', 'no', 'nope', 'na', 'nah', 'chai na'];

/// Words that say nothing about which lesson is wanted.
const _lessonStopWords = [
  'পাঠ', 'ও', 'আর', 'এবং', 'পড়ব', 'পড়তে', 'পড়ি', 'চাই', 'শুনব', 'শুনতে', 'বই',
  'আমি', 'গল্প', 'শুরু', 'করো', 'কর', 'শোনাও', 'বলো', 'নম্বর', 'নাম্বার',
  'টা', 'টি', 'lesson', 'path', 'er',
  // English function words, so "numbers" or "village" alone can name a title.
  'the', 'and', 'of', 'a', 'an', 'in', 'at', 'to', 'do',
];

bool _hasExactToken(String normalized, List<String> words) {
  final ts = tokens(normalized).toSet();
  final padded = ' $normalized ';
  for (final raw in words) {
    final w = normalizeSpeech(raw);
    if (w.isEmpty) continue;
    if (w.contains(' ') ? padded.contains(' $w ') : ts.contains(w)) return true;
  }
  return false;
}

// ---------------------------------------------------------------------------
// "Unit 2 Lesson 3", "ইউনিট দুই পাঠ তিন", "দ্বিতীয় ইউনিটের তৃতীয় পাঠ"
// ---------------------------------------------------------------------------

class UnitLessonRef {
  const UnitLessonRef({this.unit, this.lesson});
  final int? unit;
  final int? lesson;
}

int _keywordIndex(List<String> ts, List<String> rawWords) {
  final words = [for (final w in rawWords) normalizeSpeech(w)];
  for (var i = 0; i < ts.length; i++) {
    if (words.any((w) => tokenIs(ts[i], w))) return i;
  }
  return -1;
}

/// The number that belongs to the keyword at [i]: an ordinal just before it
/// ("দ্বিতীয় ইউনিট"), "X নম্বর <keyword>", or a number just after it
/// ("ইউনিট দুই", "lesson 3").
int? _numberFor(List<String> ts, int i, int other) {
  final fillers = {for (final f in _numberFillers) normalizeSpeech(f)};
  var j = i - 1;
  var skippedFiller = false;
  if (j >= 0 && fillers.contains(ts[j])) {
    j--;
    skippedFiller = true;
  }
  final before = j >= 0 ? numberOfToken(ts[j]) : null;
  if (before != null && (skippedFiller || isOrdinalToken(ts[j]))) return before;
  final after = i + 1 < ts.length ? numberOfToken(ts[i + 1]) : null;
  if (after != null) return after;
  // A bare number just before this keyword belongs to the other keyword when
  // it directly follows it ("ইউনিট দুই পাঠ" names no lesson).
  if (other >= 0 && j == other + 1) return null;
  return before;
}

/// Finds a unit and/or lesson number tied to the words "ইউনিট" / "পাঠ".
UnitLessonRef parseUnitLessonRef(String normalized) {
  final ts = tokens(normalized);
  final u = _keywordIndex(ts, unitWords);
  final l = _keywordIndex(ts, lessonWords);
  return UnitLessonRef(
    unit: u < 0 ? null : _numberFor(ts, u, l),
    lesson: l < 0 ? null : _numberFor(ts, l, u),
  );
}

// ---------------------------------------------------------------------------
// Home screen: which class?
// ---------------------------------------------------------------------------

enum ClassReplyKind { classNumber, repeat, unknown }

class ClassReply {
  const ClassReply._(this.kind, {this.classNumber, this.needsConfirmation = false});

  const ClassReply.unknown() : this._(ClassReplyKind.unknown);
  const ClassReply.repeat() : this._(ClassReplyKind.repeat);
  const ClassReply.classNumber(int n, {bool needsConfirmation = false})
      : this._(ClassReplyKind.classNumber,
            classNumber: n, needsConfirmation: needsConfirmation);

  final ClassReplyKind kind;
  final int? classNumber;

  /// True when we should ask "তুমি কি প্রথম শ্রেণির বই চাও?" before acting,
  /// because the class number came without any class/book word or the
  /// recogniser was unsure.
  final bool needsConfirmation;
}

ClassReply parseClassReply(Heard heard) {
  var sawRepeat = false;
  for (final alt in heard.normalized) {
    final nums = numbersIn(alt).where((n) => n >= 1 && n <= 12).toList();
    if (nums.isNotEmpty) {
      final hasContext = mentionsAny(alt, classWords) || mentionsAny(alt, bookWords);
      return ClassReply.classNumber(
        nums.first,
        needsConfirmation: !hasContext || heard.lowConfidence,
      );
    }
    if (mentionsAny(alt, repeatWords)) sawRepeat = true;
  }
  return sawRepeat ? const ClassReply.repeat() : const ClassReply.unknown();
}

// ---------------------------------------------------------------------------
// Yes / no
// ---------------------------------------------------------------------------

enum YesNo { yes, no, unknown }

YesNo parseYesNo(Heard heard) {
  for (final alt in heard.normalized) {
    // "চাই না" contains "চাই", so "no" is checked first.
    if (_hasExactToken(alt, _noWords)) return YesNo.no;
    if (_hasExactToken(alt, _yesWords)) return YesNo.yes;
  }
  return YesNo.unknown;
}

// ---------------------------------------------------------------------------
// Class books screen: which book?
// ---------------------------------------------------------------------------

enum BookReplyKind { book, ambiguous, repeat, back, unknown }

class BookReply {
  const BookReply(this.kind, {this.book});
  final BookReplyKind kind;
  final Book? book;
}

int _nameScore(String alt, String rawName) {
  final name = normalizeSpeech(rawName);
  if (name.isEmpty) return 0;
  if (' $alt '.contains(' $name ')) return name.length + 100;
  final altTokens = tokens(alt);
  final nameTokens = tokens(name);
  final allFound = nameTokens.every(
    (n) => altTokens.any((a) => a == n || (n.length >= 3 && tokenIs(a, n))),
  );
  return allFound ? name.length : 0;
}

BookReply parseBookChoice(Heard heard, List<Book> books) {
  if (books.isEmpty) return const BookReply(BookReplyKind.unknown);
  var sawRepeat = false;
  for (final alt in heard.normalized) {
    if (mentionsAny(alt, backWords)) return const BookReply(BookReplyKind.back);

    // By name.
    final scores = <Book, int>{};
    for (final b in books) {
      var best = 0;
      for (final n in [b.shortTitle, b.title, b.spokenLabel, ...b.spokenNames]) {
        final s = _nameScore(alt, n);
        if (s > best) best = s;
      }
      if (best > 0) scores[b] = best;
    }
    if (scores.isNotEmpty) {
      final top = scores.values.reduce((a, b) => a > b ? a : b);
      final winners = [for (final e in scores.entries) if (e.value == top) e.key];
      if (winners.length == 1) {
        return BookReply(BookReplyKind.book, book: winners.single);
      }
      return const BookReply(BookReplyKind.ambiguous);
    }

    // By position: "প্রথম বই", "এক নম্বর বই".
    final nums = numbersIn(alt);
    if (nums.isNotEmpty && mentionsAny(alt, bookWords)) {
      final i = nums.first;
      if (i >= 1 && i <= books.length) {
        return BookReply(BookReplyKind.book, book: books[i - 1]);
      }
    }
    if (mentionsAny(alt, repeatWords)) sawRepeat = true;
  }
  return BookReply(sawRepeat ? BookReplyKind.repeat : BookReplyKind.unknown);
}

// ---------------------------------------------------------------------------
// Book screen: which lesson?
// ---------------------------------------------------------------------------

enum LessonReplyKind { lesson, ambiguous, outOfRange, list, more, back, repeat, unknown }

class LessonReply {
  const LessonReply(this.kind, {this.number, this.unit, this.candidates = const []});
  final LessonReplyKind kind;

  /// Set when the child named a unit too ("ইউনিট দুই পাঠ তিন"). [number] may
  /// then be null if only the unit was named.
  final int? unit;

  /// Lesson number for [LessonReplyKind.lesson] / [LessonReplyKind.outOfRange].
  final int? number;

  /// Matching lesson numbers for [LessonReplyKind.ambiguous].
  final List<int> candidates;
}

List<String> _contentTokens(String normalized) {
  final stop = {for (final w in _lessonStopWords) normalizeSpeech(w)};
  return [for (final t in tokens(normalized)) if (!stop.contains(t)) t];
}

/// Scores how well [alt] names each lesson's title. Returns the best score
/// (share of title words said) and the lessons with that score.
(double, List<int>) _bestTitleMatch(String alt, List<Section> lessons) {
  final said = _contentTokens(alt);
  var bestScore = 0.0;
  var best = <int>[];
  if (said.isEmpty) return (bestScore, best);
  for (final l in lessons) {
    final titleTokens = _contentTokens(normalizeSpeech(l.title));
    if (titleTokens.isEmpty || l.number == null) continue;
    final matched = titleTokens
        .where((t) => said.any((s) => s == t || (t.length >= 3 && tokenIs(s, t))))
        .length;
    if (matched == 0) continue;
    final score = matched / titleTokens.length;
    if (score > bestScore) {
      bestScore = score;
      best = [l.displayNumber];
    } else if (score == bestScore) {
      best.add(l.displayNumber);
    }
  }
  return (bestScore, best);
}

LessonReply _titleReply(List<int> best) => best.length == 1
    ? LessonReply(LessonReplyKind.lesson, number: best.single)
    : LessonReply(LessonReplyKind.ambiguous, candidates: best);

LessonReply parseLessonChoice(Heard heard, List<Section> lessons) {
  var sawRepeat = false;
  for (final alt in heard.normalized) {
    if (mentionsAny(alt, backWords)) return const LessonReply(LessonReplyKind.back);
    if (mentionsAny(alt, listWords)) return const LessonReply(LessonReplyKind.list);
    if (mentionsAny(alt, moreWords)) return const LessonReply(LessonReplyKind.more);

    final ref = parseUnitLessonRef(alt);
    if (ref.unit != null) {
      return LessonReply(LessonReplyKind.lesson, unit: ref.unit, number: ref.lesson);
    }

    // A full title wins over numbers inside it ("Two Little Hands",
    // "সাত দিনের কথা"), unless a number was tied to "পাঠ"/"lesson".
    final (score, best) = _bestTitleMatch(alt, lessons);
    if (ref.lesson == null && score >= 1.0) return _titleReply(best);

    final nums = numbersIn(alt);
    if (nums.isNotEmpty) {
      final n = ref.lesson ?? nums.first;
      final exists = lessons.any((l) => l.displayNumber == n);
      return LessonReply(
        exists ? LessonReplyKind.lesson : LessonReplyKind.outOfRange,
        number: n,
      );
    }

    if (score >= 0.5) return _titleReply(best);
    if (mentionsAny(alt, repeatWords)) sawRepeat = true;
  }
  return LessonReply(sawRepeat ? LessonReplyKind.repeat : LessonReplyKind.unknown);
}

// ---------------------------------------------------------------------------
// Book with units: which unit?
// ---------------------------------------------------------------------------

enum UnitReplyKind { unit, lesson, outOfRange, needUnit, list, back, repeat, unknown }

class UnitReply {
  const UnitReply(this.kind, {this.unit, this.lesson});
  final UnitReplyKind kind;
  final int? unit;

  /// For [UnitReplyKind.lesson]: the lesson inside [unit].
  final int? lesson;
}

UnitReply parseUnitChoice(Heard heard, List<Unit> units) {
  var sawRepeat = false;
  bool exists(int n) => units.any((u) => u.number == n);
  for (final alt in heard.normalized) {
    if (mentionsAny(alt, backWords)) return const UnitReply(UnitReplyKind.back);
    if (mentionsAny(alt, listWords)) return const UnitReply(UnitReplyKind.list);

    final ref = parseUnitLessonRef(alt);
    if (ref.unit != null) {
      if (!exists(ref.unit!)) return UnitReply(UnitReplyKind.outOfRange, unit: ref.unit);
      return ref.lesson != null
          ? UnitReply(UnitReplyKind.lesson, unit: ref.unit, lesson: ref.lesson)
          : UnitReply(UnitReplyKind.unit, unit: ref.unit);
    }
    // A lesson without a unit: the child has to pick the unit first.
    if (ref.lesson != null) return const UnitReply(UnitReplyKind.needUnit);

    final nums = numbersIn(alt);
    if (nums.isNotEmpty) {
      final n = nums.first;
      return UnitReply(exists(n) ? UnitReplyKind.unit : UnitReplyKind.outOfRange, unit: n);
    }

    // By name ("greetings", "rhymes and sounds").
    final said = _contentTokens(alt);
    if (said.isNotEmpty) {
      var bestScore = 0.0;
      var best = <int>[];
      for (final u in units) {
        final titleTokens = _contentTokens(normalizeSpeech(u.title));
        if (titleTokens.isEmpty) continue;
        final matched = titleTokens
            .where((t) => said.any((s) => s == t || (t.length >= 3 && tokenIs(s, t))))
            .length;
        if (matched == 0) continue;
        final score = matched / titleTokens.length;
        if (score > bestScore) {
          bestScore = score;
          best = [u.number];
        } else if (score == bestScore) {
          best.add(u.number);
        }
      }
      if (bestScore >= 0.5 && best.length == 1) {
        return UnitReply(UnitReplyKind.unit, unit: best.single);
      }
    }
    if (mentionsAny(alt, repeatWords)) sawRepeat = true;
  }
  return UnitReply(sawRepeat ? UnitReplyKind.repeat : UnitReplyKind.unknown);
}

// ---------------------------------------------------------------------------
// Lesson player: voice commands
// ---------------------------------------------------------------------------

enum PlayerCommandKind {
  help,
  pause,
  play,
  restart,
  nextLesson,
  previousLesson,
  nextSentence,
  previousSentence,
  repeatSentence,
  goToLesson,
  back,
  unknown,
}

class PlayerCommand {
  const PlayerCommand(this.kind, {this.lessonNumber, this.unitNumber});
  final PlayerCommandKind kind;
  final int? lessonNumber;

  /// Set when a unit was named too ("ইউনিট তিন পাঠ এক").
  final int? unitNumber;
}

PlayerCommand parsePlayerCommand(Heard heard) {
  for (final alt in heard.normalized) {
    if (mentionsAny(alt, helpWords)) {
      return const PlayerCommand(PlayerCommandKind.help);
    }
    // Commands about a line come first, so "পেছনের লাইন" is not "go back"
    // and "লাইনটা আবার" does not restart the whole lesson.
    final aboutSentence = mentionsAny(alt, sentenceWords);
    if (aboutSentence) {
      if (mentionsAny(alt, [...nextWords, 'পরে', 'সামনে'])) {
        return const PlayerCommand(PlayerCommandKind.nextSentence);
      }
      if (mentionsAny(alt, [...previousWords, ...backWords, 'আগে', 'পেছনের', 'পিছনের'])) {
        return const PlayerCommand(PlayerCommandKind.previousSentence);
      }
      if (mentionsAny(alt, [...restartWords, 'এই', 'এটা', 'শোনাও'])) {
        return const PlayerCommand(PlayerCommandKind.repeatSentence);
      }
    }
    if (mentionsAny(alt, backWords) || mentionsAny(alt, listWords)) {
      return const PlayerCommand(PlayerCommandKind.back);
    }
    if (mentionsAny(alt, nextWords)) {
      return PlayerCommand(aboutSentence
          ? PlayerCommandKind.nextSentence
          : PlayerCommandKind.nextLesson);
    }
    if (mentionsAny(alt, previousWords)) {
      return PlayerCommand(aboutSentence
          ? PlayerCommandKind.previousSentence
          : PlayerCommandKind.previousLesson);
    }
    // "প্রথম থেকে" / "শুরু থেকে" mean restart, so check before numbers.
    if (mentionsAny(alt, restartWords)) {
      return const PlayerCommand(PlayerCommandKind.restart);
    }
    final ref = parseUnitLessonRef(alt);
    final nums = numbersIn(alt);
    if (ref.unit != null || nums.isNotEmpty) {
      return PlayerCommand(
        PlayerCommandKind.goToLesson,
        unitNumber: ref.unit,
        lessonNumber: ref.unit != null ? (ref.lesson ?? 1) : (ref.lesson ?? nums.first),
      );
    }
    if (mentionsAny(alt, pauseWords)) {
      return const PlayerCommand(PlayerCommandKind.pause);
    }
    if (mentionsAny(alt, playWords)) {
      return const PlayerCommand(PlayerCommandKind.play);
    }
  }
  return const PlayerCommand(PlayerCommandKind.unknown);
}
