import 'package:flutter/widgets.dart';

import 'app_state.dart';

/// Provides the composition root and session state to the widget tree.
///
/// Screens read it with `AppScope.of(context)` and rebuild using
/// `ListenableBuilder(listenable: scope.state, ...)` or their own `setState`.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.state,
    required super.child,
  });

  final AppState state;

  static AppScope of(BuildContext context) {
    final AppScope? scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this context');
    return scope!;
  }

  /// Non-listening read for callbacks that only need the repositories.
  static AppDependencies depsOf(BuildContext context) => of(context).state.deps;

  @override
  bool updateShouldNotify(AppScope oldWidget) => oldWidget.state != state;
}
