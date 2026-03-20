import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

final themeModeBoxProvider = Provider<Box>((ref) {
  return Hive.box('app_settings');
});

final appThemeModeProvider = StateNotifierProvider<AppThemeModeNotifier, ThemeMode>((ref) {
  final box = ref.watch(themeModeBoxProvider);
  return AppThemeModeNotifier(box);
});

class AppThemeModeNotifier extends StateNotifier<ThemeMode> {
  final Box _box;
  static const String _key = 'theme_mode';

  AppThemeModeNotifier(this._box) : super(ThemeMode.light) {
    _load();
  }

  void _load() {
    final raw = _box.get(_key);
    if (raw == 'dark') {
      state = ThemeMode.dark;
      return;
    }
    state = ThemeMode.light;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await _box.put(_key, mode == ThemeMode.dark ? 'dark' : 'light');
  }
}
