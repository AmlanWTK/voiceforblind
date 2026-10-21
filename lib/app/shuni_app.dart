import 'package:flutter/material.dart';

import '../content/library_repository.dart';
import '../content/models.dart';
import '../screens/home_screen.dart';
import '../services/asset_clip_player.dart';
import '../services/device_speaker.dart';
import '../services/device_speech_input.dart';
import '../voice/voice_controller.dart';
import '../widgets/voice_widgets.dart';
import 'shuni_scope.dart';
import 'theme.dart';

class ShuniApp extends StatefulWidget {
  const ShuniApp({super.key, this.voice, this.repository});

  /// Injected in tests; the real device engines are used otherwise.
  final VoiceController? voice;
  final LibraryRepository? repository;

  @override
  State<ShuniApp> createState() => _ShuniAppState();
}

class _ShuniAppState extends State<ShuniApp> with WidgetsBindingObserver {
  late final VoiceController _voice = widget.voice ??
      VoiceController(
        speaker: DeviceSpeaker(),
        speech: DeviceSpeechInput(),
        clips: AssetClipPlayer(),
      );
  late final LibraryRepository _repository = widget.repository ?? LibraryRepository();
  final _routeObserver = RouteObserver<PageRoute<dynamic>>();
  final _navigatorKey = GlobalKey<NavigatorState>();
  Library? _library;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // "হোম" from any screen.
    _voice.homeHandler = () async {
      final navigator = _navigatorKey.currentState;
      return navigator != null && await goHome(_voice, navigator);
    };
    _start();
  }

  Future<void> _start() async {
    final results = await Future.wait<Object?>([
      _voice.init(),
      _repository.load(),
    ]);
    if (!mounted) return;
    setState(() {
      _library = results[1] as Library;
      _loaded = true;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Never keep talking or listening in the background.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _voice.interrupt();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.voice == null) _voice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShuniScope(
      voice: _voice,
      library: _library ?? Library.empty,
      loaded: _loaded,
      routeObserver: _routeObserver,
      child: MaterialApp(
        title: 'শুনি',
        debugShowCheckedModeBanner: false,
        theme: buildShuniTheme(),
        navigatorKey: _navigatorKey,
        navigatorObservers: [_routeObserver],
        home: const _Root(),
      ),
    );
  }
}

/// Shows the opening screen until the library has loaded, then Home.
/// (Rebuilds through [ShuniScope] rather than by swapping MaterialApp.home.)
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    return ShuniScope.of(context).loaded ? const HomeScreen() : const _Opening();
  }
}

class _Opening extends StatelessWidget {
  const _Opening();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Semantics(
          label: 'শুনি খুলছে',
          excludeSemantics: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('শুনি', style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 20),
              const CircularProgressIndicator(color: ShuniColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
