/// Data models for Shuni's book catalog.
///
/// The catalog (assets/library/catalog.json) is generated from the DAISY
/// talking-book files by `tools/build_daisy_catalog.py`, so nothing here is
/// hand-written book content.
library;

/// A recorded audio clip inside one of a book's MP3 files.
class AudioClip {
  const AudioClip({required this.audio, required this.start, required this.end});

  final String audio;
  final Duration start;
  final Duration end;

  static AudioClip? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final audio = json['audio'];
    if (audio is! String || audio.isEmpty) return null;
    return AudioClip(
      audio: audio,
      start: _seconds(json['start']),
      end: _seconds(json['end']),
    );
  }
}

enum SegmentKind { heading, text, image, page }

/// One synchronised piece of a section: a sentence, a heading, a picture
/// (with its Bangla description) or a page-number marker.
class Segment {
  const Segment({
    required this.audio,
    required this.start,
    required this.end,
    required this.kind,
    required this.text,
    this.image,
    this.page,
  });

  final String audio;
  final Duration start;
  final Duration end;
  final SegmentKind kind;
  final String text;
  final String? image;
  final String? page;

  factory Segment.fromJson(Map<String, dynamic> json) {
    return Segment(
      audio: json['audio'] as String? ?? '',
      start: _seconds(json['start']),
      end: _seconds(json['end']),
      kind: switch (json['kind']) {
        'heading' => SegmentKind.heading,
        'image' => SegmentKind.image,
        'page' => SegmentKind.page,
        _ => SegmentKind.text,
      },
      text: json['text'] as String? ?? '',
      image: json['image'] as String?,
      page: json['page'] as String?,
    );
  }
}

enum SectionKind { lesson, front }

/// A lesson (পাঠ) or a front-matter section of a book.
class Section {
  const Section({
    required this.id,
    required this.kind,
    required this.number,
    this.unit,
    this.lessonInUnit,
    required this.title,
    required this.fullTitle,
    required this.audioFiles,
    required this.duration,
    required this.pages,
    required this.titleClip,
    required this.segments,
  });

  final String id;
  final SectionKind kind;

  /// Lesson number (1-based) through the whole book, null for front matter.
  final int? number;

  /// For books organised in units (e.g. English For Today): the unit this
  /// lesson belongs to and its printed number inside that unit.
  final int? unit;
  final int? lessonInUnit;
  final String title;
  final String fullTitle;
  final List<String> audioFiles;
  final Duration duration;
  final List<String> pages;
  final AudioClip? titleClip;
  final List<Segment> segments;

  bool get isLesson => kind == SectionKind.lesson;

  /// The number printed in the book and used when talking to the child:
  /// "Lesson 3" of a unit, or "পাঠ ৩" in a book without units.
  int get displayNumber => lessonInUnit ?? number ?? 0;

  factory Section.fromJson(Map<String, dynamic> json) {
    return Section(
      id: json['id'] as String? ?? '',
      kind: json['kind'] == 'lesson' ? SectionKind.lesson : SectionKind.front,
      number: (json['number'] as num?)?.toInt(),
      unit: (json['unit'] as num?)?.toInt(),
      lessonInUnit: (json['lessonInUnit'] as num?)?.toInt(),
      title: json['title'] as String? ?? '',
      fullTitle: json['fullTitle'] as String? ?? '',
      audioFiles: _stringList(json['audioFiles']),
      duration: _seconds(json['duration']),
      pages: _stringList(json['pages']),
      titleClip: AudioClip.fromJson(json['titleClip']),
      segments: [
        for (final s in (json['segments'] as List<dynamic>? ?? const []))
          if (s is Map<String, dynamic>) Segment.fromJson(s),
      ],
    );
  }
}

/// A unit of a book (English For Today has five), grouping its lessons.
class Unit {
  const Unit({
    required this.number,
    required this.title,
    required this.fullTitle,
    required this.titleClip,
  });

  final int number;
  final String title;
  final String fullTitle;
  final AudioClip? titleClip;

  factory Unit.fromJson(Map<String, dynamic> json) => Unit(
        number: (json['number'] as num?)?.toInt() ?? 0,
        title: json['title'] as String? ?? '',
        fullTitle: json['fullTitle'] as String? ?? '',
        titleClip: AudioClip.fromJson(json['titleClip']),
      );
}

class Book {
  const Book({
    required this.id,
    required this.classId,
    required this.title,
    required this.shortTitle,
    required this.subject,
    required this.subjectNameBn,
    required this.spokenNames,
    required this.basePath,
    required this.cover,
    required this.titleClip,
    required this.sections,
    this.units = const [],
  });

  final String id;
  final int classId;
  final String title;
  final String shortTitle;
  final String? subject;
  final String? subjectNameBn;

  /// Ways a child might say this book's name ("বাংলা বই", "bangla boi" …).
  final List<String> spokenNames;

  /// Asset folder, ending with '/'.
  final String basePath;
  final String? cover;
  final AudioClip? titleClip;
  final List<Section> sections;

  /// Empty for books whose lessons are numbered straight through.
  final List<Unit> units;

  bool get hasUnits => units.isNotEmpty;

  List<Section> get lessons =>
      sections.where((s) => s.isLesson).toList(growable: false);

  List<Section> lessonsInUnit(int unit) =>
      lessons.where((s) => s.unit == unit).toList(growable: false);

  Unit? unitByNumber(int number) {
    for (final u in units) {
      if (u.number == number) return u;
    }
    return null;
  }

  /// Finds a lesson by unit and printed lesson number.
  Section? lessonAt({int? unit, required int lesson}) {
    for (final s in lessons) {
      if (s.unit == unit && s.displayNumber == lesson) return s;
    }
    return null;
  }

  String assetPath(String fileName) => '$basePath$fileName';

  String? get coverAsset => cover == null ? null : assetPath(cover!);

  /// What the app calls this book in speech: "বাংলা বই" if the subject is
  /// known, otherwise the short title.
  String get spokenLabel =>
      subjectNameBn != null ? '$subjectNameBn বই' : shortTitle;

  factory Book.fromJson(Map<String, dynamic> json, int classId) {
    final base = json['basePath'] as String? ?? '';
    return Book(
      id: json['id'] as String? ?? '',
      classId: classId,
      title: json['title'] as String? ?? '',
      shortTitle: json['shortTitle'] as String? ?? json['title'] as String? ?? '',
      subject: json['subject'] as String?,
      subjectNameBn: json['subjectNameBn'] as String?,
      spokenNames: _stringList(json['spokenNames']),
      basePath: base.endsWith('/') ? base : '$base/',
      cover: json['cover'] as String?,
      titleClip: AudioClip.fromJson(json['titleClip']),
      sections: [
        for (final s in (json['sections'] as List<dynamic>? ?? const []))
          if (s is Map<String, dynamic>) Section.fromJson(s),
      ],
      units: [
        for (final u in (json['units'] as List<dynamic>? ?? const []))
          if (u is Map<String, dynamic>) Unit.fromJson(u),
      ],
    );
  }
}

class SchoolClass {
  const SchoolClass({required this.id, required this.nameBn, required this.books});

  final int id;
  final String nameBn;
  final List<Book> books;

  factory SchoolClass.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as num?)?.toInt() ?? 0;
    return SchoolClass(
      id: id,
      nameBn: json['nameBn'] as String? ?? '',
      books: [
        for (final b in (json['books'] as List<dynamic>? ?? const []))
          if (b is Map<String, dynamic>) Book.fromJson(b, id),
      ],
    );
  }
}

class Library {
  const Library({required this.classes});

  final List<SchoolClass> classes;

  static const empty = Library(classes: []);

  /// Classes that actually have at least one book.
  List<SchoolClass> get availableClasses =>
      classes.where((c) => c.books.isNotEmpty).toList(growable: false);

  SchoolClass? classById(int id) {
    for (final c in classes) {
      if (c.id == id && c.books.isNotEmpty) return c;
    }
    return null;
  }

  factory Library.fromJson(Map<String, dynamic> json) {
    return Library(
      classes: [
        for (final c in (json['classes'] as List<dynamic>? ?? const []))
          if (c is Map<String, dynamic>) SchoolClass.fromJson(c),
      ],
    );
  }
}

Duration _seconds(Object? value) {
  final s = value is num ? value.toDouble() : 0.0;
  return Duration(microseconds: (s * 1000000).round());
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return [for (final v in value) if (v is String) v];
}
