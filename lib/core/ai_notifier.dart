import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AiNotifier
//
// Single source of truth for the global AI Assistant panel open/close state.
//
// Uses InheritedNotifier so that:
//   • Only widgets that call AiNotifier.of(context) rebuild when isOpen changes.
//   • MaterialApp and its Navigator are never rebuilt on panel open/close.
//   • The close button reliably collapses the panel without route stack side-effects.
//
// Usage:
//   // In main.dart (once, at root):
//   AiNotifier.provide(notifier: _aiNotifier, child: ...)
//
//   // In any widget:
//   final ai = AiNotifier.of(context);
//   ai.open();  ai.close();  ai.toggle();  ai.isOpen
// ─────────────────────────────────────────────────────────────────────────────

class AiNotifier extends ChangeNotifier {
  bool _isOpen;

  AiNotifier({bool initiallyOpen = false}) : _isOpen = initiallyOpen;

  bool get isOpen => _isOpen;

  void open() {
    if (_isOpen) return;
    _isOpen = true;
    notifyListeners();
  }

  void close() {
    if (!_isOpen) return;
    _isOpen = false;
    notifyListeners();
  }

  void toggle() {
    _isOpen = !_isOpen;
    notifyListeners();
  }

  // ── InheritedNotifier accessor ────────────────────────────────────────────

  /// Returns the nearest [AiNotifier].
  /// Registers a rebuild dependency — calling widget rebuilds when [isOpen] changes.
  static AiNotifier of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_AiNotifierScope>();
    assert(
      scope != null,
      'No AiNotifier found in context. '
      'Wrap the app root with AiNotifier.provide(notifier: ..., child: ...).',
    );
    return scope!.notifier!;
  }

  /// Wraps [child] so every descendant can call [AiNotifier.of].
  /// Uses [InheritedNotifier] — only the direct consumers rebuild when the
  /// notifier fires; the root (MaterialApp / Navigator) is unaffected.
  static Widget provide({
    required AiNotifier notifier,
    required Widget child,
  }) {
    return _AiNotifierScope(notifier: notifier, child: child);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal InheritedNotifier wrapper
// Flutter's InheritedNotifier automatically calls notifyClients() on the
// ChangeNotifier, so every widget registered via dependOnInheritedWidgetOfExactType
// rebuilds exactly when isOpen changes — and nothing else does.
// ─────────────────────────────────────────────────────────────────────────────

class _AiNotifierScope extends InheritedNotifier<AiNotifier> {
  const _AiNotifierScope({
    required AiNotifier super.notifier,
    required super.child,
  });
}
