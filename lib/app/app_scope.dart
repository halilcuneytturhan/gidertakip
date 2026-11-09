import 'package:flutter/widgets.dart';

import 'app_state.dart';

/// [AppState]'i widget ağacına sağlar. Durum değiştikçe bağımlı widget'lar
/// yeniden çizilir.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  AppState get state => notifier!;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope bulunamadı');
    return scope!;
  }

  /// Yeniden çizim bağımlılığı oluşturmadan (callback'ler için).
  static AppScope read(BuildContext context) {
    final element = context.getElementForInheritedWidgetOfExactType<AppScope>();
    return element!.widget as AppScope;
  }
}
