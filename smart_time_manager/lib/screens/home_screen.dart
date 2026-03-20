import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_time_manager/models/plan_event.dart';
import 'package:smart_time_manager/providers/plan_provider.dart';
import 'package:smart_time_manager/providers/reminder_settings_provider.dart';
import 'package:smart_time_manager/providers/theme_mode_provider.dart';
import 'package:smart_time_manager/screens/quadrant_screen.dart';
import 'package:smart_time_manager/screens/calendar_screen.dart';
import 'package:smart_time_manager/screens/timeline_screen.dart';
import 'package:smart_time_manager/screens/ai_planning_screen.dart';
import 'package:smart_time_manager/screens/database_screen.dart';
import 'package:smart_time_manager/services/notification_service.dart';
import 'package:smart_time_manager/widgets/smart_input_bar.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    QuadrantScreen(),
    CalendarScreen(),
    TimelineScreen(),
    AIPlanningScreen(),
    DatabaseScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final events = ref.read(planEventsProvider);
      final settings = ref.read(reminderSettingsProvider);
      await NotificationService.instance.rescheduleAll(
        events: events,
        settings: settings,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<List<PlanEvent>>(planEventsProvider, (previous, next) async {
      final settings = ref.read(reminderSettingsProvider);
      await NotificationService.instance.rescheduleAll(
        events: next,
        settings: settings,
      );
    });

    ref.listen<ReminderSettingsState>(reminderSettingsProvider, (previous, next) async {
      final events = ref.read(planEventsProvider);
      await NotificationService.instance.rescheduleAll(
        events: events,
        settings: next,
      );
    });

    final themeMode = ref.watch(appThemeModeProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: PopupMenuButton<ThemeMode>(
                      tooltip: '外观模式',
                      icon: Icon(themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode),
                      onSelected: (mode) {
                        ref.read(appThemeModeProvider.notifier).setThemeMode(mode);
                      },
                      itemBuilder: (context) => [
                        CheckedPopupMenuItem(
                          value: ThemeMode.light,
                          checked: themeMode == ThemeMode.light,
                          child: const Text('浅色模式'),
                        ),
                        CheckedPopupMenuItem(
                          value: ThemeMode.dark,
                          checked: themeMode == ThemeMode.dark,
                          child: const Text('深色模式'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(
                  key: ValueKey(_currentIndex),
                  child: _screens[_currentIndex],
                ),
              ),
            ),
            // Hide SmartInputBar on AI screen as it has its own input
            // Hide SmartInputBar on Database screen as well
            if (_currentIndex != 3 && _currentIndex != 4) const SmartInputBar(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer.withValues(alpha: 0.75),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view),
            label: '四象限',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month),
            label: '日历',
          ),
          NavigationDestination(
            icon: Icon(Icons.view_timeline),
            label: '时间轴',
          ),
          NavigationDestination(
            icon: Icon(Icons.smart_toy),
            label: 'AI规划',
          ),
          NavigationDestination(
            icon: Icon(Icons.storage),
            label: '数据',
          ),
        ],
      ),
    );
  }
}
