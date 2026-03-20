import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

enum QuadrantType {
  importantUrgent,
  importantNotUrgent,
  urgentNotImportant,
  notImportantNotUrgent,
}

class ReminderRule {
  final bool enabled;
  final int minutesBefore;

  const ReminderRule({
    required this.enabled,
    required this.minutesBefore,
  });

  ReminderRule copyWith({
    bool? enabled,
    int? minutesBefore,
  }) {
    return ReminderRule(
      enabled: enabled ?? this.enabled,
      minutesBefore: minutesBefore ?? this.minutesBefore,
    );
  }
}

class ReminderSettingsState {
  final Map<QuadrantType, ReminderRule> rules;

  const ReminderSettingsState({required this.rules});

  factory ReminderSettingsState.defaults() {
    return ReminderSettingsState(
      rules: {
        QuadrantType.importantUrgent: const ReminderRule(enabled: true, minutesBefore: 30),
        QuadrantType.importantNotUrgent: const ReminderRule(enabled: true, minutesBefore: 30),
        QuadrantType.urgentNotImportant: const ReminderRule(enabled: true, minutesBefore: 30),
        QuadrantType.notImportantNotUrgent: const ReminderRule(enabled: true, minutesBefore: 30),
      },
    );
  }

  ReminderSettingsState copyWith({
    Map<QuadrantType, ReminderRule>? rules,
  }) {
    return ReminderSettingsState(
      rules: rules ?? this.rules,
    );
  }
}

final reminderSettingsBoxProvider = Provider<Box>((ref) {
  return Hive.box('app_settings');
});

final reminderSettingsProvider =
    StateNotifierProvider<ReminderSettingsNotifier, ReminderSettingsState>((ref) {
  final box = ref.watch(reminderSettingsBoxProvider);
  return ReminderSettingsNotifier(box);
});

class ReminderSettingsNotifier extends StateNotifier<ReminderSettingsState> {
  final Box _box;
  static const String _settingsKey = 'reminder_settings';

  ReminderSettingsNotifier(this._box) : super(ReminderSettingsState.defaults()) {
    _load();
  }

  void _load() {
    final raw = _box.get(_settingsKey);
    if (raw is! Map) {
      _save();
      return;
    }

    final loadedRules = Map<QuadrantType, ReminderRule>.from(state.rules);
    for (final type in QuadrantType.values) {
      final key = _typeKey(type);
      final item = raw[key];
      if (item is Map) {
        final enabled = item['enabled'] is bool ? item['enabled'] as bool : true;
        final minutes = item['minutesBefore'] is int ? item['minutesBefore'] as int : 30;
        loadedRules[type] = ReminderRule(
          enabled: enabled,
          minutesBefore: minutes,
        );
      }
    }
    state = state.copyWith(rules: loadedRules);
  }

  void updateEnabled(QuadrantType type, bool enabled) {
    final updated = Map<QuadrantType, ReminderRule>.from(state.rules);
    updated[type] = (updated[type] ?? const ReminderRule(enabled: true, minutesBefore: 30))
        .copyWith(enabled: enabled);
    state = state.copyWith(rules: updated);
    _save();
  }

  void updateMinutesBefore(QuadrantType type, int minutesBefore) {
    final updated = Map<QuadrantType, ReminderRule>.from(state.rules);
    updated[type] = (updated[type] ?? const ReminderRule(enabled: true, minutesBefore: 30))
        .copyWith(minutesBefore: minutesBefore);
    state = state.copyWith(rules: updated);
    _save();
  }

  void _save() {
    final map = <String, Map<String, dynamic>>{};
    for (final entry in state.rules.entries) {
      map[_typeKey(entry.key)] = {
        'enabled': entry.value.enabled,
        'minutesBefore': entry.value.minutesBefore,
      };
    }
    _box.put(_settingsKey, map);
  }

  String _typeKey(QuadrantType type) {
    switch (type) {
      case QuadrantType.importantUrgent:
        return 'important_urgent';
      case QuadrantType.importantNotUrgent:
        return 'important_not_urgent';
      case QuadrantType.urgentNotImportant:
        return 'urgent_not_important';
      case QuadrantType.notImportantNotUrgent:
        return 'not_important_not_urgent';
    }
  }
}
