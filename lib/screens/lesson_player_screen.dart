import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../app/theme.dart';
import '../content/models.dart';
import '../voice/bangla_text.dart';
import '../voice/intent_parser.dart';
import '../voice/prompts.dart';
import '../voice/voice_controller.dart';
import '../widgets/voice_screen.dart';
import '../widgets/voice_widgets.dart';

/// Plays a lesson's recorded narration from the talking book and shows the
/// sentence or picture being read. The child can pause, go a line back or
/// forward, change lesson, or say a command after tapping "কথা বলো".
class LessonPlayerScreen extends StatefulWidget {
  const LessonPlayerScreen({super.key, required this.book, required this.lessonId});

  final Book book;

  /// [Section.id] of the lesson to play.
  final String lessonId;

  @override
  State<LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class _LessonPlayerScreenState extends State<LessonPlayerScreen>
    with VoiceScreenMixin<LessonPlayerScreen>, WidgetsBindingObserver {
  final AudioPlayer _player = AudioPlayer();
  late final List<Section> _lessons = widget.book.lessons;
  late int _index = math.max(0, _lessons.indexWhere((l) => l.id == widget.lessonId));

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _stateSub;

  bool _loaded = false;
  bool _loadFailed = false;
  bool _playing = false;
  bool _completed = false;
  bool _finishHandled = false;
  int _segment = 0;
  Duration _position = Duration.zero;

  Section get _lesson => _lessons[_index];

  /// Index of lesson [lesson] in [unit] (or, in books without units, of
  /// lesson number [lesson]); null if there is no such lesson.
  int? _indexOfLesson({int? unit, required int lesson}) {
    final target = widget.book.lessonAt(unit: unit, lesson: lesson);
    if (target == null) return null;
    final i = _lessons.indexOf(target);
    return i < 0 ? null : i;
  }

  /// "পাঠ ৩" or, in a book with units, "ইউনিট ২ · পাঠ ৩".
  String _label(Section s) {
    final n = toBanglaDigits(s.displayNumber);
    return s.unit == null ? 'পাঠ $n' : 'ইউনিট ${toBanglaDigits(s.unit!)} · পাঠ $n';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _positionSub = _player.positionStream.listen(_onPosition);
    _stateSub = _player.playerStateStream.listen(_onPlayerState);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _player.pause();
    }
  }

  @override
  Future<void> onVoiceStart({required bool first}) async {
    if (!first) return;
    // "চলো, … পাঠ শুরু করি" was said on the previous screen. Load the lesson,
    // tell the child how to control it by voice, then start reading.
    final token = await voice.begin();
    await _load(autoplay: false);
    if (!mounted || _loadFailed) return;
    final guide = voice.playerGuideHeard ? Prompts.playerGuideShort : Prompts.playerGuideFull;
    final spoke = await voice.say(token, guide);
    voice.playerGuideHeard = true;
    if (!spoke || !mounted) return; // the child tapped to talk meanwhile
    voice.settle(token);
    _play();
  }

  // ---------------------------------------------------------------------------
  // Playback
  // ---------------------------------------------------------------------------

  Future<void> _load({required bool autoplay}) async {
    if (!mounted) return;
    setState(() {
      _loaded = false;
      _loadFailed = false;
      _completed = false;
      _finishHandled = false;
      _segment = 0;
      _position = Duration.zero;
    });
    try {
      final files = _lesson.audioFiles;
      if (files.isEmpty) throw StateError('lesson has no audio');
      await _player.stop();
      await _player.setAudioSources([
        for (final f in files) AudioSource.asset(widget.book.assetPath(f)),
      ]);
      if (!mounted) return;
      setState(() => _loaded = true);
      if (autoplay) _play();
    } catch (e) {
      debugPrint('Shuni: cannot load lesson ${_lesson.number}: $e');
      if (!mounted) return;
      setState(() => _loadFailed = true);
      final token = await voice.begin();
      await voice.say(token, Prompts.lessonAudioMissing);
      voice.settle(token);
    }
  }

  void _onPosition(Duration position) {
    if (!mounted || !_loaded) return;
    final files = _lesson.audioFiles;
    final fileIndex = math.max(0, math.min(_player.currentIndex ?? 0, files.length - 1));
    final file = files[fileIndex];
    final segs = _lesson.segments;
    var found = _segment;
    for (var i = 0; i < segs.length; i++) {
      final s = segs[i];
      if (s.audio == file && position >= s.start && position < s.end) {
        found = i;
        break;
      }
    }
    setState(() {
      _position = position;
      _segment = found;
    });
  }

  void _onPlayerState(PlayerState state) {
    if (!mounted) return;
    final completed = state.processingState == ProcessingState.completed;
    setState(() {
      _playing = state.playing && !completed;
      _completed = completed;
    });
    if (completed && !_finishHandled) {
      _finishHandled = true;
      _onLessonFinished();
    }
  }

  Future<void> _onLessonFinished() async {
    await _player.pause();
    final token = await voice.begin();
    final command = await voice.ask<PlayerCommand>(
      token,
      prompt: Prompts.lessonFinished,
      retryPrompt: Prompts.playerHelp,
      understand: _understand,
    );
    if (command != null && mounted) await _execute(token, command);
  }

  /// Starts playback without waiting for it to finish; failures are logged.
  void _play() {
    unawaited(_player.play().catchError((Object e) {
      debugPrint('Shuni: playback failed: $e');
    }));
  }

  Future<void> _resume() async {
    if (!_loaded) {
      await _load(autoplay: true);
    } else if (_completed) {
      await _restart();
    } else {
      _play();
    }
  }

  Future<void> _restart() async {
    _finishHandled = false;
    await _player.seek(Duration.zero, index: 0);
    _play();
  }

  Future<void> _pause(int token) async {
    await _player.pause();
    await voice.say(token, Prompts.paused);
    voice.settle(token);
  }

  /// Moves one line (sentence, heading or picture) back or forward.
  Future<void> _stepLine(int delta) async {
    if (!_loaded) return;
    final segs = _lesson.segments;
    if (segs.isEmpty) return;
    // delta -1: the line before this one; +1: the next line; 0: this line
    // again from its start. Page-number markers are skipped.
    var target = _segment + delta;
    if (delta != 0) {
      while (target >= 0 && target < segs.length && segs[target].kind == SegmentKind.page) {
        target += delta;
      }
    }
    if (target < 0) target = 0;
    if (target >= segs.length) return; // already on the last line
    final seg = segs[target];
    final fileIndex = _lesson.audioFiles.indexOf(seg.audio);
    _finishHandled = false;
    await _player.seek(seg.start, index: fileIndex < 0 ? 0 : fileIndex);
    if (mounted) setState(() => _segment = target);
    if (!_player.playing) _play();
  }

  Future<void> _changeLesson(int token, int newIndex) async {
    if (newIndex < 0 || newIndex >= _lessons.length) {
      await _player.pause();
      await voice.say(token, newIndex < 0 ? Prompts.firstLesson : Prompts.lastLesson);
      voice.settle(token);
      return;
    }
    await _player.pause();
    if (!mounted) return;
    setState(() => _index = newIndex);
    final spoke = await voice.say(
      token,
      '${Prompts.lessonStartFor(_lesson)} ${Prompts.playerGuideShort}',
    );
    voice.settle(token);
    if (!mounted) return;
    await _load(autoplay: spoke);
  }

  // ---------------------------------------------------------------------------
  // Voice commands
  // ---------------------------------------------------------------------------

  PlayerCommand? _understand(Heard heard) {
    final c = parsePlayerCommand(heard);
    return c.kind == PlayerCommandKind.unknown ? null : c;
  }

  Future<void> _execute(int token, PlayerCommand command) async {
    switch (command.kind) {
      case PlayerCommandKind.help:
        // Read all the commands, then let the child choose one.
        voice.playerGuideHeard = true;
        if (!await voice.say(token, Prompts.playerGuideFull)) return;
        final next = await voice.ask<PlayerCommand>(
          token,
          prompt: Prompts.playerAsk,
          retryPrompt: Prompts.playerHelp,
          understand: _understand,
        );
        if (next != null && next.kind != PlayerCommandKind.help && mounted) {
          await _execute(token, next);
        }
      case PlayerCommandKind.pause:
        await _pause(token);
      case PlayerCommandKind.play:
        voice.settle(token);
        await _resume();
      case PlayerCommandKind.restart:
        voice.settle(token);
        await _restart();
      case PlayerCommandKind.nextLesson:
        await _changeLesson(token, _index + 1);
      case PlayerCommandKind.previousLesson:
        await _changeLesson(token, _index - 1);
      case PlayerCommandKind.nextSentence:
        voice.settle(token);
        await _stepLine(1);
      case PlayerCommandKind.previousSentence:
        voice.settle(token);
        await _stepLine(-1);
      case PlayerCommandKind.repeatSentence:
        voice.settle(token);
        await _stepLine(0);
      case PlayerCommandKind.goToLesson:
        // "পাঠ ৩" means lesson 3 of the current unit; "ইউনিট ২ পাঠ ৩" names both.
        final book = widget.book;
        final unit = book.hasUnits ? (command.unitNumber ?? _lesson.unit) : null;
        final n = command.lessonNumber ?? 1;
        final i = _indexOfLesson(unit: unit, lesson: n);
        if (i != null) {
          await _changeLesson(token, i);
        } else {
          final String message;
          if (unit != null && book.unitByNumber(unit) == null) {
            message = Prompts.unitMissing(unit, book.units.length);
          } else if (unit != null) {
            message = Prompts.lessonMissingInUnit(unit, n, book.lessonsInUnit(unit).length);
          } else {
            message = Prompts.lessonMissing(n, _lessons.length);
          }
          await voice.say(token, message);
          voice.settle(token);
        }
      case PlayerCommandKind.back:
        _goBack();
      case PlayerCommandKind.unknown:
        voice.settle(token);
    }
  }

  // ---------------------------------------------------------------------------
  // Buttons
  // ---------------------------------------------------------------------------

  Future<void> _onTalk() async {
    if (voice.phase == VoicePhase.listening) {
      await voice.interrupt();
      return;
    }
    final wasPlaying = _playing;
    await _player.pause();
    final token = await voice.begin();
    final command = await voice.ask<PlayerCommand>(
      token,
      prompt: Prompts.playerAsk,
      retryPrompt: Prompts.playerHelp,
      understand: _understand,
    );
    if (!mounted) return;
    if (command != null) {
      await _execute(token, command);
    } else if (wasPlaying && voice.isActive(token)) {
      await _resume(); // could not understand: carry on reading
    }
  }

  Future<void> _onPlayPause() async {
    if (_playing) {
      final token = await voice.begin();
      await _pause(token);
    } else {
      await voice.interrupt();
      if (!mounted) return;
      await _resume();
    }
  }

  Future<void> _onLine(int delta) async {
    await voice.interrupt();
    if (!mounted) return;
    await _stepLine(delta);
  }

  Future<void> _onLesson(int delta) async {
    final token = await voice.begin();
    await _changeLesson(token, _index + delta);
  }

  Future<void> _onRestart() async {
    await voice.interrupt();
    if (!mounted) return;
    if (!_loaded) {
      await _load(autoplay: true);
    } else {
      await _restart();
    }
  }

  Future<void> _onSegmentTapped(int i) async {
    await voice.interrupt();
    if (!mounted || !_loaded) return;
    final seg = _lesson.segments[i];
    final fileIndex = _lesson.audioFiles.indexOf(seg.audio);
    _finishHandled = false;
    await _player.seek(seg.start, index: fileIndex < 0 ? 0 : fileIndex);
    if (mounted) setState(() => _segment = i);
    if (!_player.playing) _play();
  }

  void _goBack() {
    _player.pause();
    voice.interrupt();
    Navigator.of(context).maybePop();
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  double get _progress {
    final total = _lesson.duration.inMilliseconds;
    if (_lesson.audioFiles.length == 1 && total > 0) {
      return (_position.inMilliseconds / total).clamp(0.0, 1.0).toDouble();
    }
    final n = _lesson.segments.length;
    return n == 0 ? 0.0 : (_segment + 1) / n;
  }

  @override
  Widget build(BuildContext context) {
    final lesson = _lesson;
    final segs = lesson.segments;
    final current = segs.isEmpty ? null : segs[math.max(0, math.min(_segment, segs.length - 1))];
    final percent = toBanglaDigits((_progress * 100).round());

    return Scaffold(
      appBar: AppBar(
        leading: ShuniBackButton(onPressed: _goBack),
        actions: const [ShuniHomeButton()],
        title: Text(_label(lesson)),
      ),
      body: TapAnywhereToTalk(
        onTalk: _onTalk,
        child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            const BanglaVoiceNotice(),
            Semantics(
              header: true,
              child: Text(
                lesson.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: 10),
            Semantics(
              label: 'পাঠের $percent শতাংশ শোনা হয়েছে',
              excludeSemantics: true,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 12,
                  color: ShuniColors.primary,
                  backgroundColor: ShuniColors.outline,
                ),
              ),
            ),
            const SizedBox(height: 14),
            _NowReadingCard(
              book: widget.book,
              segment: current,
              loading: !_loaded && !_loadFailed,
              failed: _loadFailed,
            ),
            const SizedBox(height: 18),
            _PlayerControls(
              playing: _playing,
              onPlayPause: _onPlayPause,
              onPreviousLine: () => _onLine(-1),
              onNextLine: () => _onLine(1),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: BigButton(
                    icon: Icons.skip_previous,
                    label: 'আগের পাঠ',
                    outlined: true,
                    onPressed: () => _onLesson(-1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BigButton(
                    icon: Icons.skip_next,
                    label: 'পরের পাঠ',
                    outlined: true,
                    onPressed: () => _onLesson(1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            BigButton(
              icon: Icons.replay,
              label: 'আবার শুরু থেকে',
              hint: 'পাঠটি শুরু থেকে শুনতে চাপো',
              outlined: true,
              onPressed: _onRestart,
            ),
            const SizedBox(height: 22),
            const VoiceStatusLine(),
            const SizedBox(height: 16),
            Center(child: TalkButton(onPressed: _onTalk, size: 150)),
            const SizedBox(height: 28),
            Semantics(
              header: true,
              child: Text('পুরো পাঠ', style: Theme.of(context).textTheme.titleLarge),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < segs.length; i++)
              if (segs[i].kind != SegmentKind.page)
                _SegmentLine(
                  segment: segs[i],
                  current: i == _segment,
                  onTap: () => _onSegmentTapped(i),
                ),
          ],
        ),
      ),
      ),
    );
  }
}

/// The sentence or picture being read right now, shown large.
class _NowReadingCard extends StatelessWidget {
  const _NowReadingCard({
    required this.book,
    required this.segment,
    required this.loading,
    required this.failed,
  });

  final Book book;
  final Segment? segment;
  final bool loading;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final seg = segment;
    Widget body;
    if (failed) {
      body = const Text(
        'এই পাঠের অডিও পাওয়া যায়নি।',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        textAlign: TextAlign.center,
      );
    } else if (loading || seg == null) {
      body = const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (seg.kind == SegmentKind.image && seg.image != null) {
      body = Column(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: Image.asset(
              book.assetPath(seg.image!),
              semanticLabel: seg.text,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(Icons.image_not_supported, size: 64),
            ),
          ),
          const SizedBox(height: 10),
          ExcludeSemantics(
            child: Text(
              seg.text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, color: ShuniColors.inkSoft),
            ),
          ),
        ],
      );
    } else {
      final heading = seg.kind == SegmentKind.heading;
      final text = seg.kind == SegmentKind.page ? 'পৃষ্ঠা ${seg.text}' : seg.text;
      body = Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: heading ? 30 : 32,
          height: 1.4,
          fontWeight: heading ? FontWeight.w800 : FontWeight.w600,
          color: ShuniColors.ink,
        ),
      );
    }
    return Container(
      constraints: const BoxConstraints(minHeight: 180),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ShuniColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ShuniColors.outline, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (seg?.page != null && !failed)
            Align(
              alignment: Alignment.topRight,
              child: Text(
                'পৃষ্ঠা ${seg!.page}',
                style: const TextStyle(fontSize: 17, color: ShuniColors.inkSoft),
              ),
            ),
          body,
        ],
      ),
    );
  }
}

class _PlayerControls extends StatelessWidget {
  const _PlayerControls({
    required this.playing,
    required this.onPlayPause,
    required this.onPreviousLine,
    required this.onNextLine,
  });

  final bool playing;
  final VoidCallback onPlayPause;
  final VoidCallback onPreviousLine;
  final VoidCallback onNextLine;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _RoundControl(
            icon: Icons.fast_rewind,
            label: 'আগের লাইন',
            onPressed: onPreviousLine,
            size: 84,
          ),
        ),
        Expanded(
          flex: 2,
          child: _RoundControl(
            icon: playing ? Icons.pause : Icons.play_arrow,
            label: playing ? 'থামাও' : 'চালাও',
            onPressed: onPlayPause,
            size: 120,
            filled: true,
          ),
        ),
        Expanded(
          child: _RoundControl(
            icon: Icons.fast_forward,
            label: 'পরের লাইন',
            onPressed: onNextLine,
            size: 84,
          ),
        ),
      ],
    );
  }
}

class _RoundControl extends StatelessWidget {
  const _RoundControl({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.size,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : ShuniColors.primary;
    return Semantics(
      button: true,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: filled ? ShuniColors.primary : ShuniColors.surface,
            shape: CircleBorder(
              side: BorderSide(color: ShuniColors.primary, width: filled ? 0 : 3),
            ),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: SizedBox(
                width: size,
                height: size,
                child: Icon(icon, size: size * 0.5, color: fg),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// One line of the full lesson text; tapping it plays from there.
class _SegmentLine extends StatelessWidget {
  const _SegmentLine({required this.segment, required this.current, required this.onTap});

  final Segment segment;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isImage = segment.kind == SegmentKind.image;
    return Semantics(
      button: true,
      selected: current,
      label: segment.text,
      hint: 'এখান থেকে শুনতে চাপো',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: current ? ShuniColors.notice : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: current ? ShuniColors.talk : ShuniColors.outline,
              width: current ? 3 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isImage ? Icons.image_outlined : Icons.short_text,
                color: ShuniColors.inkSoft,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  segment.text,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: segment.kind == SegmentKind.heading
                        ? FontWeight.w800
                        : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
