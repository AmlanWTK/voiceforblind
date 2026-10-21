import 'package:flutter/widgets.dart';

import '../content/models.dart';
import '../voice/voice_controller.dart';

/// Gives every screen access to the shared voice controller, the loaded
/// library and the route observer.
class ShuniScope extends InheritedWidget {
  const ShuniScope({
    super.key,
    required this.voice,
    required this.library,
    required this.loaded,
    required this.routeObserver,
    required super.child,
  });

  final VoiceController voice;
  final Library library;

  /// False until the catalog has been read.
  final bool loaded;
  final RouteObserver<PageRoute<dynamic>> routeObserver;

  static ShuniScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ShuniScope>();
    assert(scope != null, 'ShuniScope not found above this widget');
    return scope!;
  }

  @override
  bool updateShouldNotify(ShuniScope oldWidget) =>
      voice != oldWidget.voice ||
      library != oldWidget.library ||
      loaded != oldWidget.loaded ||
      routeObserver != oldWidget.routeObserver;
}
