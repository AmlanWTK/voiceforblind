import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../content/models.dart';
import '../voice/bangla_text.dart';
import '../voice/intent_parser.dart';
import '../voice/prompts.dart';
import '../voice/voice_controller.dart';
import '../widgets/voice_screen.dart';
import '../widgets/voice_widgets.dart';
import 'book_screen.dart';

/// Lists the books of one class. Reads each title aloud — using the
/// narrator's own recording from the talking book when there is one — and
/// lets the child choose by name or by tapping.
class ClassBooksScreen extends StatefulWidget {
  const ClassBooksScreen({super.key, required this.schoolClass});

  final SchoolClass schoolClass;

  @override
  State<ClassBooksScreen> createState() => _ClassBooksScreenState();
}

class _ClassBooksScreenState extends State<ClassBooksScreen>
    with VoiceScreenMixin<ClassBooksScreen> {
  List<Book> get _books => widget.schoolClass.books;

  /// "বাংলা বই অথবা ইংরেজি বই"
  String get _example =>
      Prompts.bookExamples([for (final b in _books) b.spokenLabel]);

  @override
  Future<void> onVoiceStart({required bool first}) async {
    final token = await voice.begin();
    if (first) {
      if (!await voice.say(token, Prompts.classBooksWelcome(widget.schoolClass.id))) return;
      if (!await _readTitles(token)) return;
      await _askForBook(token, Prompts.askBook(_example));
    } else {
      await _askForBook(token, Prompts.askBook(_example));
    }
  }

  Future<bool> _readTitles(int token) async {
    if (!await voice.say(token, Prompts.bookCount(_books.length))) return false;
    for (var i = 0; i < _books.length; i++) {
      final b = _books[i];
      if (_books.length > 1 && !await voice.say(token, Prompts.bookNumber(i + 1))) {
        return false;
      }
      if (!await voice.playClipOrSay(token, b, b.titleClip, b.title)) return false;
    }
    return true;
  }

  Future<void> _askForBook(int token, String prompt) async {
    final reply = await voice.ask<BookReply>(
      token,
      prompt: prompt,
      retryPrompt: Prompts.askBookAgain(_example),
      understand: (heard) {
        final r = parseBookChoice(heard, _books);
        return r.kind == BookReplyKind.unknown ? null : r;
      },
    );
    if (reply == null || !mounted) return;
    switch (reply.kind) {
      case BookReplyKind.book:
        await _openBook(token, reply.book!);
      case BookReplyKind.ambiguous:
        await _askForBook(token, Prompts.whichBookAmbiguous);
      case BookReplyKind.repeat:
        if (await _readTitles(token)) await _askForBook(token, Prompts.askBook(_example));
      case BookReplyKind.back:
        _goBack();
      case BookReplyKind.unknown:
        break;
    }
  }

  Future<void> _openBook(int token, Book book) async {
    if (!await voice.say(token, Prompts.bookChosen(book.spokenLabel))) return;
    voice.settle(token);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => BookScreen(book: book),
    ));
  }

  Future<void> _onTalk() async {
    if (voice.phase == VoicePhase.listening) {
      await voice.interrupt();
      return;
    }
    final token = await voice.begin();
    await _askForBook(token, Prompts.askBook(_example));
  }

  Future<void> _onRepeat() async {
    final token = await voice.begin();
    if (await _readTitles(token)) await _askForBook(token, Prompts.askBook(_example));
  }

  Future<void> _onBookTapped(Book book) async {
    final token = await voice.begin();
    await _openBook(token, book);
  }

  void _goBack() {
    voice.interrupt();
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: ShuniBackButton(onPressed: _goBack),
        actions: const [ShuniHomeButton()],
        title: Text('${classNameBn(widget.schoolClass.id)}র বই'),
      ),
      body: TapAnywhereToTalk(
        onTalk: _onTalk,
        child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const BanglaVoiceNotice(),
            const VoiceStatusLine(),
            const SizedBox(height: 20),
            Center(child: TalkButton(onPressed: _onTalk, size: 168)),
            const SizedBox(height: 20),
            BigButton(
              icon: Icons.replay,
              label: 'বইয়ের নাম আবার শোনো',
              hint: 'সব বইয়ের নাম আবার শুনতে চাপো',
              outlined: true,
              onPressed: _onRepeat,
            ),
            const SizedBox(height: 24),
            Semantics(
              header: true,
              child: Text(
                '${countBn(_books.length)} বই',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 12),
            for (final book in _books) ...[
              _BookCard(book: book, onTap: () => _onBookTapped(book)),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  const _BookCard({required this.book, required this.onTap});

  final Book book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cover = book.coverAsset;
    return Semantics(
      button: true,
      label: '${book.title}। ${countBn(book.lessons.length)} পাঠ',
      hint: 'বইটি খুলতে চাপো',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: ShuniColors.surface,
        borderRadius: BorderRadius.circular(20),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 96,
                    height: 128,
                    child: cover == null
                        ? const _CoverPlaceholder()
                        : Image.asset(
                            cover,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const _CoverPlaceholder(),
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(book.shortTitle, style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 6),
                      Text(
                        '${countBn(book.lessons.length)} পাঠ',
                        style: const TextStyle(fontSize: 19, color: ShuniColors.inkSoft),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 40, color: ShuniColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: ShuniColors.notice,
      child: Center(child: Icon(Icons.menu_book, size: 48, color: ShuniColors.primary)),
    );
  }
}
