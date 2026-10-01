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

  /// Screens hold on to values read during build (the signed-in user, say), so
  /// every rebuild of [AppScope] — which only happens when [AppState] notifies
  /// — has to reach them. Comparing the [state] instance would always be false
  /// because it is the same object for the life of the app.
  @override
  bool updateShouldNotify(AppScope oldWidget) => true;
}
