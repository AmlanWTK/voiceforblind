// Checks the generated catalog against the files actually bundled with the
// app: every lesson's narration MP3 and every picture must load.
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuni/content/models.dart';
import 'package:shuni/voice/bangla_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Library library;

  Book bookById(String id) =>
      library.classById(1)!.books.firstWhere((b) => b.id == id);

  setUpAll(() async {
    final raw = await rootBundle.loadString('assets/library/catalog.json');
    library = Library.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  });

  test('Class 1 has the Bangla book with 53 lessons in order', () {
    final book = bookById('amar_bangla_boi_class1');
    // Compare normalised text: য়/ড় can be stored precomposed or decomposed.
    String n(String s) => normalizeSpeech(s);
    expect(n(book.title), n('আমার বাংলা বই - প্রথম শ্রেণি'));
    expect(book.lessons.length, 53);
    expect(
      book.lessons.map((l) => l.number).toList(),
      List<int>.generate(53, (i) => i + 1),
    );
    expect(n(book.lessons.first.title), n('আমার পরিচয়'));
    expect(n(book.lessons[8].title), n('বাঘ ও রাখাল'));
    expect(n(book.lessons.last.title), n('আমার ঠিকানা'));
  });

  test('Class 1 also has English For Today: 5 units, 39 lessons', () {
    final book = bookById('english_for_today_class1');
    expect(book.title, 'English For Today - Class One');
    expect(book.units.map((u) => u.number).toList(), [1, 2, 3, 4, 5]);
    expect(book.lessons.length, 39);
    // Every unit's lessons are numbered 1..N as printed.
    for (final u in book.units) {
      final nums = book.lessonsInUnit(u.number).map((l) => l.lessonInUnit).toList();
      expect(nums, List<int>.generate(nums.length, (i) => i + 1), reason: u.fullTitle);
    }
    expect(book.lessonsInUnit(2).length, 21);
    expect(book.lessonAt(unit: 1, lesson: 3)!.title, 'How Are You?');
    // Unit 2 Lesson 10 is split over two recordings in the DAISY book.
    expect(book.lessonAt(unit: 2, lesson: 10)!.audioFiles, ['aud023.mp3', 'aud024.mp3']);
  });

  test('every lesson has narration and synced segments', () {
    for (final book in library.classById(1)!.books) {
      for (final l in book.lessons) {
        expect(l.audioFiles, isNotEmpty, reason: l.fullTitle);
        expect(l.segments, isNotEmpty, reason: l.fullTitle);
        expect(l.titleClip, isNotNull, reason: l.fullTitle);
        expect(l.duration, greaterThan(Duration.zero), reason: l.fullTitle);
      }
    }
  });

  test('all referenced audio files are bundled', () async {
    for (final book in library.classById(1)!.books) {
      final files = <String>{
        for (final s in book.sections) ...s.audioFiles,
        if (book.titleClip != null) book.titleClip!.audio,
        for (final u in book.units)
          if (u.titleClip != null) u.titleClip!.audio,
      };
      for (final f in files) {
        final data = await rootBundle.load(book.assetPath(f));
        expect(data.lengthInBytes, greaterThan(1000), reason: '${book.id}/$f');
      }
    }
  });

  test('all referenced pictures and the cover are bundled', () async {
    for (final book in library.classById(1)!.books) {
      final images = <String>{
        for (final s in book.sections)
          for (final seg in s.segments)
            if (seg.image != null) seg.image!,
        if (book.cover != null) book.cover!,
      };
      expect(images.length, greaterThan(100), reason: book.id);
      for (final img in images) {
        final data = await rootBundle.load(book.assetPath(img));
        expect(data.lengthInBytes, greaterThan(0), reason: '${book.id}/$img');
      }
    }
  });
}
