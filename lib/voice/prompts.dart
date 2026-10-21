/// Every sentence Shuni speaks, in one place so wording can be reviewed and
/// changed without touching screen code. Short, friendly, child-level Bangla.
library;

import '../content/models.dart';
import 'bangla_text.dart';

class Prompts {
  Prompts._();

  // Home
  static const greeting = 'হ্যালো বন্ধু! আমি শুনি।';
  static const askClass = 'অ্যাপটি খুলেছে। তুমি কোন শ্রেণির বই পড়তে চাও?';
  static const askClassAgain = 'তুমি কোন শ্রেণির বই পড়তে চাও?';
  static const notUnderstoodClass =
      'আমি বুঝতে পারিনি। আবার বলো, তুমি কোন শ্রেণির বই পড়তে চাও?';
  static String confirmClass(int n) =>
      'তুমি কি ${classNameBn(n)}র বই পড়তে চাও? হ্যাঁ অথবা না বলো।';
  static String classChosen(int n) =>
      'তুমি ${classNameBn(n)}র বই বেছে নিয়েছ। চলো, বইগুলো দেখি।';
  static String classNotAvailable(int n, int available) =>
      '${classNameBn(n)}র বই এখনো আসেনি। এখন ${classNameBn(available)}র বই আছে। '
      '${classNameBn(available)}র বই পড়তে চাও? হ্যাঁ অথবা না বলো।';
  static const noLibrary =
      'দুঃখিত, বইগুলো খুলতে পারছি না। বড় কাউকে ডাকো।';

  // Getting help when voice does not work
  static const tapToTalk =
      'কথা বলতে চাইলে পর্দার যেকোনো জায়গায় একবার চাপ দাও, তারপর বলো।';
  static const micPermissionComing =
      'এখন মাইক্রোফোন চালুর অনুমতি চাওয়া হবে। অনুমতি দাও বোতামে চাপ দাও। দরকার হলে বড় কারও সাহায্য নাও।';
  static const micDenied =
      'মাইক্রোফোনের অনুমতি নেই, তাই আমি তোমার কথা শুনতে পাচ্ছি না। নিচের বোতাম চেপে বেছে নাও।';
  static const speechUnavailable =
      'এই ফোনে কথা শোনার ব্যবস্থা নেই। নিচের বোতাম চেপে বেছে নাও।';
  static const speechNetwork =
      'ইন্টারনেটে সমস্যা হচ্ছে, তাই তোমার কথা বুঝতে পারছি না। একটু পরে বড় বোতাম চেপে আবার বলো।';
  static const speechNoBangla =
      'এই ফোন এখনো বাংলা কথা চিনতে পারে না। নিচের বোতাম চেপে বেছে নাও।';
  static const speechError =
      'কথা শুনতে একটু সমস্যা হলো। বড় বোতাম চেপে আবার বলো।';
  static const yesOrNo = 'হ্যাঁ অথবা না বলো।';
  static const okWaiting = 'ঠিক আছে।';
  static const goingHome = 'ঠিক আছে, শুরুর পাতায় যাচ্ছি।';

  // Class books
  static String classBooksWelcome(int n) => '${classNameBn(n)}র বইয়ের বিভাগে স্বাগতম।';
  static String bookCount(int count) => 'এখানে ${countBn(count)} বই আছে।';
  static String bookNumber(int i) => 'বই ${toBanglaDigits(i)}।';
  static String askBook(String examples) =>
      'কোন বই পড়তে চাও? বইয়ের নাম বলো, যেমন, $examples।';
  static String askBookAgain(String examples) =>
      'আমি বুঝতে পারিনি। বইয়ের নাম আবার বলো, যেমন, $examples।';

  /// "বাংলা বই অথবা ইংরেজি বই"
  static String bookExamples(List<String> labels) => labels.take(3).join(' অথবা ');
  static String bookChosen(String spokenLabel) => 'তুমি $spokenLabel বেছে নিয়েছ।';
  static const whichBookAmbiguous = 'কোন বইটি? বইয়ের পুরো নাম বলো।';

  // Book (lesson chooser)
  static const bookOpened = 'বইটি খোলা হয়েছে।';
  static String lessonCount(int n) => 'এই বইয়ে ${countBn(n)} পাঠ আছে।';
  static const askLesson =
      'কোন পাঠ পড়তে চাও? যেমন বলো, প্রথম পাঠ। সব পাঠের নাম শুনতে বলো, সূচি।';
  static const askLessonShort = 'কোন পাঠ পড়তে চাও?';
  static const notUnderstoodLesson =
      'আমি বুঝতে পারিনি। পাঠের নম্বর বলো, যেমন, প্রথম পাঠ। নাম শুনতে বলো, সূচি।';
  static String lessonMissing(int n, int max) =>
      'এই বইয়ে ${toBanglaDigits(n)} নম্বর পাঠ নেই। এক থেকে ${toBanglaDigits(max)} এর মধ্যে একটি নম্বর বলো।';
  static String lessonsAmbiguous(List<int> numbers) {
    if (numbers.length > 4) {
      return 'এই নামে অনেকগুলো পাঠ আছে। পাঠের নম্বর বলো।';
    }
    final list = numbers.map((n) => 'পাঠ ${toBanglaDigits(n)}').join(', ');
    return 'এই নামে কয়েকটি পাঠ আছে: $list। কোন নম্বরের পাঠ পড়তে চাও?';
  }
  static const listMore =
      'আরও পাঠের নাম শুনতে বলো, আরও। কোনো পাঠ পড়তে চাইলে তার নম্বর বলো।';
  static const listEnd = 'সব পাঠের নাম বলা শেষ। কোন পাঠ পড়তে চাও?';
  static String lessonStart(int n) => 'চলো, ${lessonNameBn(n)} শুরু করি।';

  /// "চলো, প্রথম পাঠ শুরু করি।" or, in a book with units,
  /// "চলো, দ্বিতীয় ইউনিটের তৃতীয় পাঠ শুরু করি।"
  static String lessonStartFor(Section lesson) => lesson.unit == null
      ? lessonStart(lesson.displayNumber)
      : 'চলো, ${unitNameBn(lesson.unit!)}ের ${lessonNameBn(lesson.displayNumber)} শুরু করি।';

  // Books with units (English For Today)
  static String unitCount(int n) => 'এই বইয়ে ${countBn(n)} ইউনিট আছে।';
  static const askUnit =
      'কোন ইউনিট পড়তে চাও? যেমন বলো, প্রথম ইউনিট। সব ইউনিটের নাম শুনতে বলো, সূচি।';
  static const askUnitShort = 'কোন ইউনিট পড়তে চাও?';
  static const notUnderstoodUnit =
      'আমি বুঝতে পারিনি। ইউনিটের নম্বর বলো, যেমন, প্রথম ইউনিট। নাম শুনতে বলো, সূচি।';
  static String unitMissing(int n, int max) =>
      'এই বইয়ে ${toBanglaDigits(n)} নম্বর ইউনিট নেই। এক থেকে ${toBanglaDigits(max)} এর মধ্যে একটি নম্বর বলো।';
  static String unitChosen(int n) => 'তুমি ${unitNameBn(n)} বেছে নিয়েছ।';
  static const unitFirst = 'আগে ইউনিট বেছে নাও। যেমন বলো, প্রথম ইউনিট।';
  static const unitListEnd = 'সব ইউনিটের নাম বলা শেষ। কোন ইউনিট পড়তে চাও?';
  static String lessonCountInUnit(int n) => 'এই ইউনিটে ${countBn(n)} পাঠ আছে।';
  static String lessonMissingInUnit(int unit, int n, int max) =>
      '${unitNameBn(unit)}ে ${toBanglaDigits(n)} নম্বর পাঠ নেই। এক থেকে ${toBanglaDigits(max)} এর মধ্যে একটি নম্বর বলো।';

  // Lesson player
  static const playerAsk = 'কী করতে চাও? বলো।';

  /// Said the first time a lesson opens: how to control it by voice.
  static const playerGuideFull =
      'পাঠ শোনার সময় কিছু বলতে চাইলে পর্দার যেকোনো জায়গায় একবার চাপ দাও, তারপর বলো। '
      'থামাতে বলো, থামো। আবার চালাতে বলো, চালাও। '
      'আগের লাইন শুনতে বলো, আগের লাইন। পরের লাইন শুনতে বলো, পরের লাইন। '
      'এই লাইনটাই আবার শুনতে বলো, লাইন আবার। '
      'পাঠটি শুরু থেকে শুনতে বলো, আবার। অন্য পাঠে যেতে বলো, পরের পাঠ, অথবা আগের পাঠ। '
      'পাঠের তালিকায় ফিরতে বলো, ফিরে যাও। একদম শুরুর পাতায় যেতে বলো, হোম। '
      'এই নিয়মগুলো আবার শুনতে বলো, সাহায্য।';

  /// Said whenever any later lesson opens: the three main commands.
  static const playerGuideShort =
      'কিছু বলতে চাইলে পর্দায় চাপ দাও, তারপর বলো, থামো, আগের লাইন, অথবা পরের লাইন। '
      'সব নিয়ম শুনতে বলো, সাহায্য।';
  static const lessonFinished =
      'পাঠটি শেষ হয়েছে। আবার শুনতে বলো, আবার। পরের পাঠ শুনতে বলো, পরের পাঠ।';
  static const lastLesson = 'এটাই বইয়ের শেষ পাঠ।';
  static const firstLesson = 'এটাই বইয়ের প্রথম পাঠ।';
  static const playerHelp =
      'আমি বুঝতে পারিনি। বলতে পারো, থামো, চালাও, আগের লাইন, পরের লাইন, আবার, পরের পাঠ, হোম, অথবা সাহায্য।';
  static const lessonAudioMissing =
      'দুঃখিত, এই পাঠের অডিও খুঁজে পাওয়া যায়নি। অন্য পাঠ বেছে নাও।';
  static const paused = 'থামানো হয়েছে।';
}
