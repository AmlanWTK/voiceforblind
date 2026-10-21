import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../content/models.dart';
import '../voice/bangla_text.dart';
import '../voice/intent_parser.dart';
import '../voice/prompts.dart';
import '../voice/voice_controller.dart';
import '../widgets/voice_screen.dart';
import '../widgets/voice_widgets.dart';
import 'lesson_player_screen.dart';

/// An opened book.
///
/// Books numbered straight through (আমার বাংলা বই): announces the title,
/// then the child picks a lesson by number ("প্রথম পাঠ", "পাঠ ৯"), by name
/// ("বাঘ ও রাখাল"), or hears the names in groups ("সূচি" … "আরও").
///
/// Books organised in units (English For Today): the same screen first asks
/// for a unit ("দ্বিতীয় ইউনিট"), then opens again for that unit's lessons.
/// "ইউনিট দুই পাঠ তিন" jumps straight to a lesson.
class BookScreen extends StatefulWidget {
  const BookScreen({super.key, required this.book, this.unit});

  final Book book;

  /// The unit whose lessons are shown, for books with units.
  final Unit? unit;

  @override
  State<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends State<BookScreen> with VoiceScreenMixin<BookScreen> {
  static const _namesPerGroup = 5;

  Book get _book => widget.book;

  /// True on the first level of a book with units: choose a unit.
  bool get _choosingUnit => _book.hasUnits && widget.unit == null;

  late final List<Section> _lessons = widget.unit == null
      ? widget.book.lessons
      : widget.book.lessonsInUnit(widget.unit!.number);

  /// Where the spoken lesson list continues on "আরও".
  int _listPosition = 0;

  @override
  Future<void> onVoiceStart({required bool first}) async {
    final token = await voice.begin();
    if (_choosingUnit) {
      if (first) {
        if (!await voice.playClipOrSay(token, _book, _book.titleClip, _book.title)) return;
        if (!await voice.say(
          token,
          '${Prompts.bookOpened} ${Prompts.unitCount(_book.units.length)}',
        )) {
          return;
        }
        await _unitConversation(token, Prompts.askUnit);
      } else {
        await _unitConversation(token, Prompts.askUnitShort);
      }
      return;
    }
    if (first) {
      final unit = widget.unit;
      if (unit != null) {
        if (!await voice.playClipOrSay(token, _book, unit.titleClip, unit.fullTitle)) return;
        if (!await voice.say(token, Prompts.lessonCountInUnit(_lessons.length))) return;
      } else {
        if (!await voice.playClipOrSay(token, _book, _book.titleClip, _book.title)) return;
        if (!await voice.say(
          token,
          '${Prompts.bookOpened} ${Prompts.lessonCount(_lessons.length)}',
        )) {
          return;
        }
      }
      await _lessonConversation(token, Prompts.askLesson);
    } else {
      await _lessonConversation(token, Prompts.askLessonShort);
    }
  }

  // ---------------------------------------------------------------------------
  // Choosing a unit
  // ---------------------------------------------------------------------------

  Future<void> _unitConversation(int token, String firstPrompt) async {
    final units = _book.units;
    var prompt = firstPrompt;
    for (var turn = 0; turn < 12; turn++) {
      final reply = await voice.ask<UnitReply>(
        token,
        prompt: prompt,
        retryPrompt: Prompts.notUnderstoodUnit,
        understand: (heard) {
          final r = parseUnitChoice(heard, units);
          return r.kind == UnitReplyKind.unknown ? null : r;
        },
      );
      if (reply == null || !mounted) return;
      switch (reply.kind) {
        case UnitReplyKind.unit:
          await _openUnit(token, _book.unitByNumber(reply.unit!)!);
          return;
        case UnitReplyKind.lesson:
          final lesson = _book.lessonAt(unit: reply.unit, lesson: reply.lesson!);
          if (lesson == null) {
            prompt = Prompts.lessonMissingInUnit(
              reply.unit!,
              reply.lesson!,
              _book.lessonsInUnit(reply.unit!).length,
            );
          } else {
            await _openLesson(token, lesson);
            return;
          }
        case UnitReplyKind.outOfRange:
          prompt = Prompts.unitMissing(reply.unit!, units.length);
        case UnitReplyKind.needUnit:
          prompt = Prompts.unitFirst;
        case UnitReplyKind.list:
          for (final u in units) {
            if (!await voice.playClipOrSay(token, _book, u.titleClip, u.fullTitle)) return;
          }
          prompt = Prompts.unitListEnd;
        case UnitReplyKind.back:
          _goBack();
          return;
        case UnitReplyKind.repeat:
        case UnitReplyKind.unknown:
          prompt = Prompts.askUnit;
      }
    }
    voice.settle(token);
  }

  Future<void> _openUnit(int token, Unit unit, {bool replace = false}) async {
    if (!await voice.say(token, Prompts.unitChosen(unit.number))) return;
    voice.settle(token);
    if (!mounted) return;
    final route = MaterialPageRoute<void>(
      builder: (_) => BookScreen(book: _book, unit: unit),
    );
    final nav = Navigator.of(context);
    if (replace) {
      await nav.pushReplacement(route);
    } else {
      await nav.push(route);
    }
  }

  // ---------------------------------------------------------------------------
  // Choosing a lesson
  // ---------------------------------------------------------------------------

  /// Keeps the conversation going until a lesson is chosen, the child goes
  /// back, or they stop answering. Each turn needs a reply from the child,
  /// so this never loops on its own.
  Future<void> _lessonConversation(int token, String firstPrompt) async {
    var prompt = firstPrompt;
    for (var turn = 0; turn < 12; turn++) {
      final reply = await voice.ask<LessonReply>(
        token,
        prompt: prompt,
        retryPrompt: Prompts.notUnderstoodLesson,
        understand: (heard) {
          final r = parseLessonChoice(heard, _lessons);
          return r.kind == LessonReplyKind.unknown ? null : r;
        },
      );
      if (reply == null || !mounted) return;
      switch (reply.kind) {
        case LessonReplyKind.lesson:
          final next = await _resolveLesson(token, reply);
          if (next == null) return; // opened something
          prompt = next;
        case LessonReplyKind.outOfRange:
          prompt = _missingPrompt(reply.number!);
        case LessonReplyKind.ambiguous:
          prompt = Prompts.lessonsAmbiguous(reply.candidates);
        case LessonReplyKind.list:
          _listPosition = 0;
          final more = await _readLessonNames(token);
          if (more == null) return;
          prompt = more ? Prompts.listMore : Prompts.listEnd;
        case LessonReplyKind.more:
          if (_listPosition >= _lessons.length) _listPosition = 0;
          final more = await _readLessonNames(token);
          if (more == null) return;
          prompt = more ? Prompts.listMore : Prompts.listEnd;
        case LessonReplyKind.back:
          _goBack();
          return;
        case LessonReplyKind.repeat:
        case LessonReplyKind.unknown:
          prompt = Prompts.askLesson;
      }
    }
    voice.settle(token);
  }

  String _missingPrompt(int n) => widget.unit == null
      ? Prompts.lessonMissing(n, _lessons.length)
      : Prompts.lessonMissingInUnit(widget.unit!.number, n, _lessons.length);

  /// Opens the lesson (or unit) the child asked for. Returns null when
  /// something was opened, otherwise the next thing to ask.
  Future<String?> _resolveLesson(int token, LessonReply reply) async {
    final unitNumber = reply.unit;
    if (unitNumber != null && _book.hasUnits) {
      final unit = _book.unitByNumber(unitNumber);
      if (unit == null) return Prompts.unitMissing(unitNumber, _book.units.length);
      final n = reply.number;
      if (n == null) {
        // Only a unit was named: show that unit's lessons instead.
        await _openUnit(token, unit, replace: widget.unit != null);
        return null;
      }
      final lesson = _book.lessonAt(unit: unitNumber, lesson: n);
      if (lesson == null) {
        return Prompts.lessonMissingInUnit(unitNumber, n, _book.lessonsInUnit(unitNumber).length);
      }
      await _openLesson(token, lesson);
      return null;
    }
    final n = reply.number;
    if (n == null) return Prompts.askLesson;
    for (final l in _lessons) {
      if (l.displayNumber == n) {
        await _openLesson(token, l);
        return null;
      }
    }
    return _missingPrompt(n);
  }

  /// Reads the next group of lesson titles in the narrator's voice.
  /// Returns whether more remain, or null if interrupted.
  Future<bool?> _readLessonNames(int token) async {
    final end = math.min(_listPosition + _namesPerGroup, _lessons.length);
    for (var i = _listPosition; i < end; i++) {
      final l = _lessons[i];
      if (!await voice.playClipOrSay(token, _book, l.titleClip, l.fullTitle)) {
        return null;
      }
      _listPosition = i + 1;
    }
    return _listPosition < _lessons.length;
  }

  Future<void> _openLesson(int token, Section lesson) async {
    if (!await voice.say(token, Prompts.lessonStartFor(lesson))) return;
    voice.settle(token);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => LessonPlayerScreen(book: _book, lessonId: lesson.id),
    ));
  }

  // ---------------------------------------------------------------------------
  // Buttons
  // ---------------------------------------------------------------------------

  Future<void> _onTalk() async {
    if (voice.phase == VoicePhase.listening) {
      await voice.interrupt();
      return;
    }
    final token = await voice.begin();
    if (_choosingUnit) {
      await _unitConversation(token, Prompts.askUnitShort);
    } else {
      await _lessonConversation(token, Prompts.askLessonShort);
    }
  }

  Future<void> _onRepeat() async {
    final token = await voice.begin();
    if (_choosingUnit) {
      await _unitConversation(token, Prompts.askUnit);
    } else {
      await _lessonConversation(token, Prompts.askLesson);
    }
  }

  Future<void> _onLessonTapped(Section lesson) async {
    final token = await voice.begin();
    await _openLesson(token, lesson);
  }

  Future<void> _onUnitTapped(Unit unit) async {
    final token = await voice.begin();
    await _openUnit(token, unit);
  }

  void _goBack() {
    voice.interrupt();
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final unit = widget.unit;
    final title = unit == null
        ? _book.shortTitle
        : 'ইউনিট ${toBanglaDigits(unit.number)}';
    final listHeader = _choosingUnit
        ? 'ইউনিটের তালিকা — ${countBn(_book.units.length)} ইউনিট'
        : 'পাঠের তালিকা — ${countBn(_lessons.length)} পাঠ';
    final itemCount = _choosingUnit ? _book.units.length : _lessons.length;
    return Scaffold(
      appBar: AppBar(
        leading: ShuniBackButton(onPressed: _goBack),
        actions: const [ShuniHomeButton()],
        title: Text(title),
      ),
      body: TapAnywhereToTalk(
        onTalk: _onTalk,
        child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              sliver: SliverList.list(
                children: [
                  const BanglaVoiceNotice(),
                  if (unit != null) ...[
                    Text(
                      unit.title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 10),
                  ],
                  const VoiceStatusLine(),
                  const SizedBox(height: 16),
                  Center(child: TalkButton(onPressed: _onTalk, size: 156)),
                  const SizedBox(height: 16),
                  BigButton(
                    icon: Icons.replay,
                    label: 'আবার শোনো',
                    hint: 'কী বলতে হবে আবার শুনতে চাপো',
                    outlined: true,
                    onPressed: _onRepeat,
                  ),
                  const SizedBox(height: 24),
                  Semantics(
                    header: true,
                    child: Text(listHeader, style: Theme.of(context).textTheme.titleLarge),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              sliver: SliverList.separated(
                itemCount: itemCount,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  if (_choosingUnit) {
                    final u = _book.units[i];
                    return _NumberedTile(
                      number: u.number,
                      title: u.title,
                      subtitle: '${countBn(_book.lessonsInUnit(u.number).length)} পাঠ',
                      semanticsPrefix: 'ইউনিট',
                      hint: 'ইউনিটটি খুলতে চাপো',
                      trailing: Icons.chevron_right,
                      onTap: () => _onUnitTapped(u),
                    );
                  }
                  return _LessonTile(
                    lesson: _lessons[i],
                    onTap: () => _onLessonTapped(_lessons[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({required this.lesson, required this.onTap});

  final Section lesson;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pages = lesson.pages.isEmpty
        ? null
        : lesson.pages.length == 1
            ? 'পৃষ্ঠা ${lesson.pages.first}'
            : 'পৃষ্ঠা ${lesson.pages.first}–${lesson.pages.last}';
    return _NumberedTile(
      number: lesson.displayNumber,
      title: lesson.title,
      subtitle: pages,
      semanticsPrefix: 'পাঠ',
      hint: 'পাঠটি শুনতে চাপো',
      trailing: Icons.play_circle_fill,
      onTap: onTap,
    );
  }
}

/// A large list row: a numbered circle, a title, an optional subtitle.
/// Read by TalkBack as one item, e.g. "পাঠ ৩। How Are You?। পৃষ্ঠা ৬–৭".
class _NumberedTile extends StatelessWidget {
  const _NumberedTile({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.semanticsPrefix,
    required this.hint,
    required this.trailing,
    required this.onTap,
  });

  final int number;
  final String title;
  final String? subtitle;
  final String semanticsPrefix;
  final String hint;
  final IconData trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = toBanglaDigits(number);
    final sub = subtitle;
    return Semantics(
      button: true,
      label: '$semanticsPrefix $n। $title${sub == null ? '' : '। $sub'}',
      hint: hint,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: ShuniColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 76),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: ShuniColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      n,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: Theme.of(context).textTheme.titleLarge),
                        if (sub != null)
                          Text(
                            sub,
                            style: const TextStyle(fontSize: 17, color: ShuniColors.inkSoft),
                          ),
                      ],
                    ),
                  ),
                  Icon(trailing, size: 40, color: ShuniColors.talk),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
