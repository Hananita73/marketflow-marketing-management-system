import 'package:flutter/material.dart';

/// Single source of truth for the app's [ThemeMode].
///
/// Consume via [ThemeNotifier.of] anywhere in the widget tree.
/// In [main.dart] the root [MarketingApp] listens with [ListenableBuilder]
/// and feeds [themeMode] into [MaterialApp].
class ThemeNotifier extends ChangeNotifier {
  ThemeMode _mode;

  ThemeNotifier({ThemeMode initial = ThemeMode.light}) : _mode = initial;

  // ── Public API ────────────────────────────────────────────────────────────

  ThemeMode get mode => _mode;

  /// Convenience: true when the effective mode is dark (also respects System).
  bool isDark(BuildContext context) {
    if (_mode == ThemeMode.system) {
      return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
    return _mode == ThemeMode.dark;
  }

  void setMode(ThemeMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }

  /// Convenience toggle: Light ↔ Dark (never System).
  void toggle() {
    _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  // ── InheritedWidget-style accessor ────────────────────────────────────────

  static ThemeNotifier of(BuildContext context) {
    final notifier =
        context.dependOnInheritedWidgetOfExactType<_ThemeNotifierScope>();
    assert(notifier != null,
        'No ThemeNotifier found in context. Wrap your app with ThemeNotifierProvider.');
    return notifier!.notifier;
  }

  /// Wraps [child] so that any descendant can call [ThemeNotifier.of(context)].
  static Widget provide({
    required ThemeNotifier notifier,
    required Widget child,
  }) {
    return ListenableBuilder(
      listenable: notifier,
      builder: (context, _) => _ThemeNotifierScope(notifier: notifier, child: child),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal InheritedWidget
// ─────────────────────────────────────────────────────────────────────────────

class _ThemeNotifierScope extends InheritedWidget {
  final ThemeNotifier notifier;

  const _ThemeNotifierScope({
    required this.notifier,
    required super.child,
  });

  @override
  bool updateShouldNotify(_ThemeNotifierScope old) =>
      notifier.mode != old.notifier.mode;
}
