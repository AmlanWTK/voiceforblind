/// Bangla text helpers: normalising recognised speech, reading numbers in
/// Bangla, English and Banglish, and formatting numbers for speech.
library;

const _bnDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];

/// 12 -> "১২"
String toBanglaDigits(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (final unit in s.codeUnits) {
    final d = unit - 0x30;
    b.write(d >= 0 && d <= 9 ? _bnDigits[d] : String.fromCharCode(unit));
  }
  return b.toString();
}

final _punctuation = RegExp(r'''[।॥,.?!:;\-–—"'“”‘’()\[\]{}/\\|]''');
final _digitThenOther = RegExp(r'(\d)(?=[^\d\s])');
final _otherThenDigit = RegExp(r'([^\d\s])(?=\d)');
final _spaces = RegExp(r'\s+');

/// Lower-cases, unifies Bangla spellings that speech engines produce in more
/// than one Unicode form, converts Bangla digits to ASCII, strips
/// punctuation and splits digits from words ("1er" -> "1 er").
String normalizeSpeech(String input) {
  var s = input.toLowerCase();
  // Precomposed vs decomposed nukta letters.
  s = s
      .replaceAll('য়', 'য়') // য়
      .replaceAll('ড়', 'ড়') // ড়
      .replaceAll('ঢ়', 'ঢ়') // ঢ়
      .replaceAll('‌', '')
      .replaceAll('‍', '')
      .replaceAll('শ্রেণী', 'শ্রেণি');
  final b = StringBuffer();
  for (final rune in s.runes) {
    final i = rune - 0x09E6; // Bangla digit zero
    b.write(i >= 0 && i <= 9 ? '$i' : String.fromCharCode(rune));
  }
  s = b.toString().replaceAll(_punctuation, ' ');
  s = s.replaceAllMapped(_digitThenOther, (m) => '${m[1]} ');
  s = s.replaceAllMapped(_otherThenDigit, (m) => '${m[1]} ');
  return s.replaceAll(_spaces, ' ').trim();
}

List<String> tokens(String normalized) =>
    normalized.isEmpty ? const [] : normalized.split(' ');

/// Endings a Bangla word can carry and still mean the same number or name:
/// "ওয়ানের", "পাঁচটা", "প্রথমটি", "দশে", "class 1 er".
const _rawSuffixes = [
  '', 'ের', 'এর', 'র', 'টা', 'টি', 'টো', 'টার', 'টির', 'টাই', 'টাতে', 'টিতে', 'ে',
  'তে', 'য়ের', 'য়', 'য়ে', 'ম', 's', 'th',
];

final Set<String> _suffixes = {for (final s in _rawSuffixes) normalizeSpeech(s)};

/// True if [token] is [word] or [word] plus one of the allowed endings.
/// Both arguments must already be normalised with [normalizeSpeech].
bool tokenIs(String token, String word) {
  if (word.isEmpty || !token.startsWith(word)) return false;
  return _suffixes.contains(token.substring(word.length));
}

/// Number words a child (or the speech engine) may use, in Bangla, English
/// and Banglish. Ordinals map to their number. Spelling variants are
/// harmless: the list is normalised (and de-duplicated) before use.
const List<(String, int)> _numberWordList = [
  // Bangla cardinals
  ('এক', 1), ('দুই', 2), ('দুয়ে', 2), ('দু', 2), ('তিন', 3), ('চার', 4),
  ('পাঁচ', 5), ('ছয়', 6), ('ছয়', 6), ('সাত', 7), ('আট', 8), ('নয়', 9),
  ('দশ', 10), ('এগারো', 11), ('এগার', 11), ('বারো', 12), ('তেরো', 13),
  ('তের', 13), ('চৌদ্দ', 14), ('চোদ্দ', 14), ('পনেরো', 15), ('পনের', 15),
  ('ষোলো', 16), ('ষোল', 16), ('সতেরো', 17), ('সতের', 17), ('আঠারো', 18),
  ('আঠার', 18), ('উনিশ', 19), ('বিশ', 20), ('কুড়ি', 20), ('একুশ', 21),
  ('বাইশ', 22), ('তেইশ', 23), ('চব্বিশ', 24), ('পঁচিশ', 25), ('ছাব্বিশ', 26),
  ('সাতাশ', 27), ('আটাশ', 28), ('উনত্রিশ', 29), ('ত্রিশ', 30), ('তিরিশ', 30),
  ('একত্রিশ', 31), ('বত্রিশ', 32), ('তেত্রিশ', 33), ('চৌত্রিশ', 34),
  ('পঁয়ত্রিশ', 35), ('ছত্রিশ', 36), ('সাঁইত্রিশ', 37), ('আটত্রিশ', 38),
  ('উনচল্লিশ', 39), ('চল্লিশ', 40), ('একচল্লিশ', 41), ('বিয়াল্লিশ', 42),
  ('তেতাল্লিশ', 43), ('চুয়াল্লিশ', 44), ('পঁয়তাল্লিশ', 45), ('ছেচল্লিশ', 46),
  ('সাতচল্লিশ', 47), ('আটচল্লিশ', 48), ('উনপঞ্চাশ', 49), ('পঞ্চাশ', 50),
  ('একান্ন', 51), ('বাহান্ন', 52), ('তিপ্পান্ন', 53), ('চুয়ান্ন', 54),
  ('পঞ্চান্ন', 55),
  // Bangla ordinals
  ('প্রথম', 1), ('দ্বিতীয়', 2), ('তৃতীয়', 3), ('চতুর্থ', 4), ('পঞ্চম', 5),
  ('ষষ্ঠ', 6), ('সপ্তম', 7), ('অষ্টম', 8), ('নবম', 9), ('দশম', 10),
  // English spoken, written in Bangla script
  ('ওয়ান', 1), ('টু', 2), ('থ্রি', 3), ('ফোর', 4), ('ফাইভ', 5), ('সিক্স', 6),
  ('সেভেন', 7), ('এইট', 8), ('নাইন', 9), ('টেন', 10), ('ফার্স্ট', 1),
  ('সেকেন্ড', 2), ('থার্ড', 3),
  // English
  ('one', 1), ('won', 1), ('two', 2), ('three', 3), ('four', 4), ('five', 5),
  ('six', 6), ('seven', 7), ('eight', 8), ('nine', 9), ('ten', 10),
  ('eleven', 11), ('twelve', 12), ('first', 1), ('second', 2), ('third', 3),
  ('fourth', 4), ('fifth', 5), ('sixth', 6), ('seventh', 7), ('eighth', 8),
  ('ninth', 9), ('tenth', 10),
  // Banglish (Bangla in Latin letters)
  ('ek', 1), ('dui', 2), ('tin', 3), ('panch', 5), ('pach', 5), ('choy', 6),
  ('sat', 7), ('noy', 9), ('dosh', 10), ('prothom', 1), ('protham', 1),
  ('ditiyo', 2), ('tritiyo', 3),
];

final Map<String, int> numberWords = () {
  final map = <String, int>{};
  for (final (word, value) in _numberWordList) {
    map.putIfAbsent(normalizeSpeech(word), () => value);
  }
  return map;
}();

/// The number a single normalised token stands for, or null.
int? numberOfToken(String token) {
  final digits = int.tryParse(token);
  if (digits != null) return digits;
  // Prefer the longest matching word so "একুশ" is 21, not "এক" + ending.
  String? best;
  for (final w in numberWords.keys) {
    if (tokenIs(token, w) && (best == null || w.length > best.length)) best = w;
  }
  return best == null ? null : numberWords[best];
}

const _rawOrdinals = [
  'প্রথম', 'দ্বিতীয়', 'তৃতীয়', 'চতুর্থ', 'পঞ্চম', 'ষষ্ঠ', 'সপ্তম', 'অষ্টম', 'নবম',
  'দশম', 'ফার্স্ট', 'সেকেন্ড', 'থার্ড', 'first', 'second', 'third', 'fourth',
  'fifth', 'sixth', 'seventh', 'eighth', 'ninth', 'tenth', 'prothom', 'protham',
  'ditiyo', 'tritiyo',
];
final Set<String> _ordinals = {for (final o in _rawOrdinals) normalizeSpeech(o)};

/// True if [token] is an ordinal word ("দ্বিতীয়", "দ্বিতীয়টি", "second").
bool isOrdinalToken(String token) => _ordinals.any((o) => tokenIs(token, o));

/// Numbers mentioned in [normalized] text, in order. Digits ("5") and number
/// words ("পাঁচ", "পঞ্চম", "five", "ওয়ানের") are both understood.
List<int> numbersIn(String normalized) => [
      for (final t in tokens(normalized))
        if (numberOfToken(t) case final n?) n,
    ];

/// True if any token of [normalized] is one of [words] (with endings).
bool mentionsAny(String normalized, Iterable<String> words) {
  final ts = tokens(normalized);
  for (final raw in words) {
    final w = normalizeSpeech(raw);
    if (w.isEmpty) continue;
    if (w.contains(' ')) {
      if (' $normalized '.contains(' $w ')) return true;
      continue;
    }
    for (final t in ts) {
      if (tokenIs(t, w)) return true;
    }
  }
  return false;
}

const _ordinalNames = {
  1: 'প্রথম',
  2: 'দ্বিতীয়',
  3: 'তৃতীয়',
  4: 'চতুর্থ',
  5: 'পঞ্চম',
  6: 'ষষ্ঠ',
  7: 'সপ্তম',
  8: 'অষ্টম',
  9: 'নবম',
  10: 'দশম',
};

/// "দ্বিতীয় ইউনিট", "১২ নম্বর ইউনিট"
String unitNameBn(int n) =>
    _ordinalNames.containsKey(n) ? '${_ordinalNames[n]} ইউনিট' : '${toBanglaDigits(n)} নম্বর ইউনিট';

/// "প্রথম শ্রেণি", "পঞ্চম শ্রেণি", "১১ শ্রেণি"
String classNameBn(int n) => '${_ordinalNames[n] ?? toBanglaDigits(n)} শ্রেণি';

/// "প্রথম পাঠ" for 1–10, otherwise "১২ নম্বর পাঠ".
String lessonNameBn(int n) =>
    _ordinalNames.containsKey(n) ? '${_ordinalNames[n]} পাঠ' : '${toBanglaDigits(n)} নম্বর পাঠ';

const _smallCountWords = {
  1: 'একটি',
  2: 'দুটি',
  3: 'তিনটি',
  4: 'চারটি',
  5: 'পাঁচটি',
};

/// "একটি", "দুটি", … "৫৩টি"
String countBn(int n) => _smallCountWords[n] ?? '${toBanglaDigits(n)}টি';
