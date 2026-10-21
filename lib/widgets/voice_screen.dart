import 'package:flutter/material.dart';

import '../app/shuni_scope.dart';
import '../content/models.dart';
import '../voice/voice_controller.dart';

/// Shared behaviour for Shuni's voice-led screens.
///
/// [onVoiceStart] runs when the screen first appears (`first: true`) and
/// again whenever the child comes back to it (`first: false`), so every
/// screen introduces itself out loud. With TalkBack on, Shuni waits a moment
/// so TalkBack's own announcement of the new screen is not talked over.
mixin VoiceScreenMixin<T extends StatefulWidget> on State<T> implements RouteAware {
  late VoiceController voice;
  late Library library;
  RouteObserver<PageRoute<dynamic>>? _observer;

  Future<void> onVoiceStart({required bool first});

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = ShuniScope.of(context);
    voice = scope.voice;
    library = scope.library;
    final route = ModalRoute.of(context);
    if (_observer == null && route is PageRoute) {
      _observer = scope.routeObserver;
      _observer!.subscribe(this, route); // calls didPush()
    }
  }

  @override
  void dispose() {
    _observer?.unsubscribe(this);
    super.dispose();
  }

  void _scheduleStart({required bool first}) {
    final talkBackOn = MediaQuery.accessibleNavigationOf(context);
    final delay = Duration(milliseconds: talkBackOn ? 1400 : 350);
    Future<void>.delayed(delay, () {
      if (!mounted) return;
      // Only the screen on top may talk.
      if (ModalRoute.of(context)?.isCurrent ?? false) onVoiceStart(first: first);
    });
  }

  @override
  void didPush() => _scheduleStart(first: true);

  @override
  void didPopNext() => _scheduleStart(first: false);

  @override
  void didPushNext() {}

  /// Popped by the back button or gesture: stop talking/listening at once.
  @override
  void didPop() => voice.interrupt();
}
