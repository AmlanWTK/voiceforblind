import 'package:flutter_test/flutter_test.dart';
import 'package:shuni/content/models.dart';
import 'package:shuni/voice/bangla_text.dart';
import 'package:shuni/voice/intent_parser.dart';

Heard h(String s, {bool low = false}) => Heard([s], lowConfidence: low);

Section lesson(int n, String title) => Section(
      id: 'l$n',
      kind: SectionKind.lesson,
      number: n,
      title: title,
      fullTitle: 'পাঠ ${toBanglaDigits(n)} - $title',
      audioFiles: const ['a.mp3'],
      duration: Duration.zero,
      pages: const [],
      titleClip: null,
      segments: const [],
    );

// A few real lesson titles from আমার বাংলা বই (Class 1).
final lessons = [
  lesson(1, 'আমার পরিচয়'),
  lesson(5, 'আঁকাআঁকি'),
  lesson(7, 'আঁকাআঁকি'),
  lesson(9, 'বাঘ ও রাখাল'),
  lesson(10, 'বর্ণ শিখি : অ আ'),
  lesson(11, 'বর্ণ শিখি : ই ঈ'),
  lesson(25, 'ট্রেন'),
  lesson(40, 'মামার বাড়ি'),
  lesson(53, 'আমার ঠিকানা'),
];

const banglaBook = Book(
  id: 'amar_bangla_boi_class1',
  classId: 1,
  title: 'আমার বাংলা বই - প্রথম শ্রেণি',
  shortTitle: 'আমার বাংলা বই',
  subject: 'bangla',
  subjectNameBn: 'বাংলা',
  spokenNames: ['বাংলা', 'বাংলা বই', 'আমার বাংলা বই', 'bangla', 'bangla boi'],
  basePath: 'assets/x/',
  cover: null,
  titleClip: null,
  sections: [],
);

const englishBook = Book(
  id: 'english_for_today_class1',
  classId: 1,
  title: 'English For Today - Class One',
  shortTitle: 'English For Today',
  subject: 'english',
  subjectNameBn: 'ইংরেজি',
  spokenNames: ['ইংরেজি', 'ইংরেজি বই', 'ইংলিশ', 'ইংলিশ বই', 'english', 'english book'],
  basePath: 'assets/y/',
  cover: null,
  titleClip: null,
  sections: [],
);

void main() {
  group('normalizeSpeech', () {
    test('Bangla digits, punctuation and digit/word splitting', () {
      expect(normalizeSpeech('ক্লাস ১।'), 'ক্লাস 1');
      expect(normalizeSpeech('Class 1er boi?'), 'class 1 er boi');
      expect(normalizeSpeech('পাঠ ১২-এর'), 'পাঠ 12 এর');
    });

    test('decomposed and precomposed য় are treated the same', () {
      expect(normalizeSpeech('ওয়ান'), normalizeSpeech('ওয়ান'));
    });
  });

  group('numbersIn', () {
    test('digits and words', () {
      expect(numbersIn(normalizeSpeech('ক্লাস ওয়ানের বই')), [1]);
      expect(numbersIn(normalizeSpeech('প্রথম শ্রেণির বই')), [1]);
      expect(numbersIn(normalizeSpeech('পাঁচ নম্বর পাঠ')), [5]);
      expect(numbersIn(normalizeSpeech('একুশ')), [21]);
      expect(numbersIn(normalizeSpeech('class one')), [1]);
      expect(numbersIn(normalizeSpeech('পাঠ ৫৩')), [53]);
      expect(numbersIn(normalizeSpeech('দশম পাঠ')), [10]);
    });

    test('ordinary words are not numbers', () {
      expect(numbersIn(normalizeSpeech('একটু বাংলা বই পড়ব')), isEmpty);
      expect(numbersIn(normalizeSpeech('ছবি দেখি')), isEmpty);
    });
  });

  group('parseClassReply', () {
    for (final said in [
      'ক্লাস ওয়ানের বই',
      'ক্লাস ১',
      'প্রথম শ্রেণির বই',
      'Class one',
      'Class 1 er boi',
      'ক্লাস 1 এর বই',
      'আমি প্রথম শ্রেণীর বই পড়তে চাই',
    ]) {
      test('"$said" -> class 1 without confirmation', () {
        final r = parseClassReply(h(said));
        expect(r.kind, ClassReplyKind.classNumber);
        expect(r.classNumber, 1);
        expect(r.needsConfirmation, isFalse);
      });
    }

    test('a bare number asks for confirmation', () {
      final r = parseClassReply(h('এক'));
      expect(r.classNumber, 1);
      expect(r.needsConfirmation, isTrue);
    });

    test('low recogniser confidence asks for confirmation', () {
      final r = parseClassReply(h('ক্লাস ওয়ান', low: true));
      expect(r.needsConfirmation, isTrue);
    });

    test('other classes are recognised', () {
      expect(parseClassReply(h('ক্লাস টু')).classNumber, 2);
      expect(parseClassReply(h('তৃতীয় শ্রেণি')).classNumber, 3);
    });

    test('second alternative is used when the first has no class', () {
      final r = parseClassReply(Heard(['ক্লাস ওয়াশ', 'ক্লাস ওয়ান']));
      expect(r.classNumber, 1);
    });

    test('nonsense is unknown, "আবার" is repeat', () {
      expect(parseClassReply(h('আমি জানি না')).kind, ClassReplyKind.unknown);
      expect(parseClassReply(h('আবার বলো')).kind, ClassReplyKind.repeat);
    });
  });

  group('parseYesNo', () {
    test('yes', () {
      expect(parseYesNo(h('হ্যাঁ')), YesNo.yes);
      expect(parseYesNo(h('হ্যাঁ চাই')), YesNo.yes);
      expect(parseYesNo(h('yes')), YesNo.yes);
    });
    test('no wins over চাই', () {
      expect(parseYesNo(h('না')), YesNo.no);
      expect(parseYesNo(h('চাই না')), YesNo.no);
    });
    test('unknown', () {
      expect(parseYesNo(h('বাঘ')), YesNo.unknown);
    });
  });

  group('parseBookChoice', () {
    final books = [banglaBook, englishBook];
    test('English book by Bangla or English name', () {
      expect(parseBookChoice(h('ইংরেজি বই'), books).book, englishBook);
      expect(parseBookChoice(h('ইংলিশ বই পড়ব'), books).book, englishBook);
      expect(parseBookChoice(h('english book'), books).book, englishBook);
      expect(parseBookChoice(h('দ্বিতীয় বই'), books).book, englishBook);
    });
    test('by name', () {
      expect(parseBookChoice(h('বাংলা বই পড়ব'), books).book, banglaBook);
      expect(parseBookChoice(h('আমার বাংলা বই'), books).book, banglaBook);
      expect(parseBookChoice(h('bangla boi'), books).book, banglaBook);
    });
    test('by position', () {
      expect(parseBookChoice(h('প্রথম বই'), books).book, banglaBook);
    });
    test('back and unknown', () {
      expect(parseBookChoice(h('ফিরে যাও'), books).kind, BookReplyKind.back);
      expect(parseBookChoice(h('অংক বই'), books).kind, BookReplyKind.unknown);
    });
  });

  group('parseLessonChoice', () {
    test('by number in many forms', () {
      for (final said in ['প্রথম পাঠ', 'পাঠ ১', 'এক নম্বর পাঠ', 'lesson one']) {
        final r = parseLessonChoice(h(said), lessons);
        expect(r.kind, LessonReplyKind.lesson, reason: said);
        expect(r.number, 1, reason: said);
      }
      expect(parseLessonChoice(h('পাঠ ৯'), lessons).number, 9);
      expect(parseLessonChoice(h('তিপ্পান্ন নম্বর পাঠ'), lessons).number, 53);
    });

    test('number that does not exist', () {
      final r = parseLessonChoice(h('পাঠ ৯০'), lessons);
      expect(r.kind, LessonReplyKind.outOfRange);
      expect(r.number, 90);
    });

    test('by title', () {
      final r = parseLessonChoice(h('বাঘ ও রাখাল পড়ব'), lessons);
      expect(r.kind, LessonReplyKind.lesson);
      expect(r.number, 9);
      expect(parseLessonChoice(h('মামার বাড়ি'), lessons).number, 40);
      expect(parseLessonChoice(h('ট্রেন'), lessons).number, 25);
    });

    test('same title twice is ambiguous', () {
      final r = parseLessonChoice(h('আঁকাআঁকি'), lessons);
      expect(r.kind, LessonReplyKind.ambiguous);
      expect(r.candidates, [5, 7]);
    });

    test('list, more, back', () {
      expect(parseLessonChoice(h('সূচি'), lessons).kind, LessonReplyKind.list);
      expect(parseLessonChoice(h('আরও'), lessons).kind, LessonReplyKind.more);
      expect(parseLessonChoice(h('ফিরে যাও'), lessons).kind, LessonReplyKind.back);
    });
  });

  group('parsePlayerCommand', () {
    PlayerCommandKind k(String s) => parsePlayerCommand(h(s)).kind;
    test('commands', () {
      expect(k('থামো'), PlayerCommandKind.pause);
      expect(k('বন্ধ করো'), PlayerCommandKind.pause);
      expect(k('চালাও'), PlayerCommandKind.play);
      expect(k('আবার'), PlayerCommandKind.restart);
      expect(k('আবার শুরু করো'), PlayerCommandKind.restart);
      expect(k('প্রথম থেকে'), PlayerCommandKind.restart);
      expect(k('পরের পাঠ'), PlayerCommandKind.nextLesson);
      expect(k('আগের পাঠ'), PlayerCommandKind.previousLesson);
      expect(k('পরের লাইন'), PlayerCommandKind.nextSentence);
      expect(k('আগের লাইন'), PlayerCommandKind.previousSentence);
      expect(k('আগের লাইনে যাও'), PlayerCommandKind.previousSentence);
      expect(k('পেছনের লাইন'), PlayerCommandKind.previousSentence);
      expect(k('লাইন আবার'), PlayerCommandKind.repeatSentence);
      expect(k('এই লাইনটা আবার বলো'), PlayerCommandKind.repeatSentence);
      expect(k('পরের লাইনে যাও'), PlayerCommandKind.nextSentence);
      expect(k('ফিরে যাও'), PlayerCommandKind.back);
      expect(k('হাতি ঘোড়া'), PlayerCommandKind.unknown);
      expect(k('সাহায্য'), PlayerCommandKind.help);
      expect(k('কী বলব'), PlayerCommandKind.help);
      expect(k('help'), PlayerCommandKind.help);
    });
    test('go to a lesson', () {
      final c = parsePlayerCommand(h('পাঠ পাঁচ'));
      expect(c.kind, PlayerCommandKind.goToLesson);
      expect(c.lessonNumber, 5);
    });
  });

  group('units (English For Today)', () {
    final units = [
      for (final (n, t) in [
        (1, 'Greetings and Farewells'),
        (2, 'The Alphabet and Numbers'),
        (3, 'Classroom Instructions'),
        (4, 'Questions and Answers'),
        (5, 'Rhymes and Sounds'),
      ])
        Unit(number: n, title: t, fullTitle: 'Unit - $n $t', titleClip: null),
    ];

    test('unit and lesson references in many forms', () {
      UnitLessonRef ref(String s) => parseUnitLessonRef(normalizeSpeech(s));
      for (final (said, u, l) in [
        ('ইউনিট দুই পাঠ তিন', 2, 3),
        ('দ্বিতীয় ইউনিটের তৃতীয় পাঠ', 2, 3),
        ('unit 2 lesson 3', 2, 3),
        ('ইউনিট ২ এর লেসন ৩', 2, 3),
        ('দুই নম্বর ইউনিটের তিন নম্বর পাঠ', 2, 3),
        ('ইউনিট টু', 2, null),
        ('পঞ্চম ইউনিট', 5, null),
      ]) {
        expect(ref(said).unit, u, reason: said);
        expect(ref(said).lesson, l, reason: said);
      }
      expect(ref('পাঁচ নম্বর পাঠ').lesson, 5);
      // A unit's number is not reused as the lesson's.
      expect(ref('ইউনিট দুই পাঠ').unit, 2);
      expect(ref('ইউনিট দুই পাঠ').lesson, isNull);
      expect(ref('পাঠ পাঁচ').unit, isNull);
    });

    test('choosing a unit', () {
      UnitReply u(String s) => parseUnitChoice(h(s), units);
      expect(u('দ্বিতীয় ইউনিট').unit, 2);
      expect(u('ইউনিট দুই').kind, UnitReplyKind.unit);
      expect(u('তিন').unit, 3);
      expect(u('rhymes and sounds').unit, 5);
      expect(u('ইউনিট নয়').kind, UnitReplyKind.outOfRange);
      expect(u('প্রথম পাঠ').kind, UnitReplyKind.needUnit);
      expect(u('সূচি').kind, UnitReplyKind.list);
      expect(u('ফিরে যাও').kind, UnitReplyKind.back);
      final direct = u('ইউনিট দুই পাঠ তিন');
      expect(direct.kind, UnitReplyKind.lesson);
      expect((direct.unit, direct.lesson), (2, 3));
    });

    test('inside a unit, lessons use their printed numbers', () {
      final unit1 = [
        for (final (i, t) in [(1, 'Good Morning (1)'), (2, 'Good Morning (2)'), (3, 'How Are You?')])
          Section(
            id: 'u1l$i',
            kind: SectionKind.lesson,
            number: i,
            unit: 1,
            lessonInUnit: i,
            title: t,
            fullTitle: 'Lesson $i - $t',
            audioFiles: const ['a.mp3'],
            duration: Duration.zero,
            pages: const [],
            titleClip: null,
            segments: const [],
          ),
      ];
      final r = parseLessonChoice(h('তৃতীয় পাঠ'), unit1);
      expect((r.kind, r.number, r.unit), (LessonReplyKind.lesson, 3, null));
      final other = parseLessonChoice(h('ইউনিট দুই পাঠ এক'), unit1);
      expect((other.unit, other.number), (2, 1));
      expect(parseLessonChoice(h('good morning'), unit1).kind, LessonReplyKind.ambiguous);
      expect(parseLessonChoice(h('how are you'), unit1).number, 3);
    });

    test('a title with number words is matched as a title', () {
      Section l(int i, String t) => Section(
            id: 'u2l$i',
            kind: SectionKind.lesson,
            number: i,
            unit: 2,
            lessonInUnit: i,
            title: t,
            fullTitle: 'Lesson $i- $t',
            audioFiles: const ['a.mp3'],
            duration: Duration.zero,
            pages: const [],
            titleClip: null,
            segments: const [],
          );
      final unit2 = [l(2, 'aA bB'), l(5, 'Two Little Hands'), l(10, 'Numbers 5 6')];
      expect(parseLessonChoice(h('two little hands'), unit2).number, 5);
      expect(parseLessonChoice(h('numbers 5 6'), unit2).number, 10);
      expect(parseLessonChoice(h('lesson two'), unit2).number, 2);
      expect(parseUnitChoice(h('alphabet'), units).unit, 2);
    });

    test('player: go to a lesson in another unit', () {
      final c = parsePlayerCommand(h('ইউনিট তিন পাঠ দুই'));
      expect(c.kind, PlayerCommandKind.goToLesson);
      expect((c.unitNumber, c.lessonNumber), (3, 2));
    });
  });

  group('isHomeRequest', () {
    test('home from anywhere', () {
      for (final said in ['হোম', 'হোমে যাও', 'home', 'শুরুর পাতায় যাও', 'প্রথম পাতায় চলো']) {
        expect(isHomeRequest(h(said)), isTrue, reason: said);
      }
      for (final said in ['মামার বাড়ি', 'প্রথম পাঠ', 'ফিরে যাও', 'আবার']) {
        expect(isHomeRequest(h(said)), isFalse, reason: said);
      }
    });
  });

  group('speech formatting', () {
    test('Bangla numbers and names', () {
      expect(toBanglaDigits(53), '৫৩');
      expect(classNameBn(1), 'প্রথম শ্রেণি');
      expect(lessonNameBn(1), 'প্রথম পাঠ');
      expect(lessonNameBn(12), '১২ নম্বর পাঠ');
      expect(countBn(1), 'একটি');
      expect(countBn(53), '৫৩টি');
    });
  });
}
