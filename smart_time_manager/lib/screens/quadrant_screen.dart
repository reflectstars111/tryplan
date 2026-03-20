import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_time_manager/models/plan_event.dart';
import 'package:smart_time_manager/providers/plan_provider.dart';
import 'package:smart_time_manager/providers/reminder_settings_provider.dart';
import 'package:smart_time_manager/providers/selected_date_provider.dart';
import 'package:smart_time_manager/widgets/date_strip_widget.dart';
import 'package:intl/intl.dart';

class QuadrantScreen extends ConsumerWidget {
  const QuadrantScreen({super.key});

  static const Color _darkQuadrantRed = Color(0xFF5A1E1E);
  static const Color _darkQuadrantBlue = Color(0xFF1E3F66);
  static const Color _darkQuadrantYellow = Color(0xFF5B4A14);
  static const Color _darkQuadrantGrey = Color(0xFF35393F);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allEvents = ref.watch(planEventsProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final quadrantEvents = allEvents.where((e) {
      if (e.isCountdown) {
        if (e.deadline == null) return false;
        final selected = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
        final today = DateTime.now();
        final todayDay = DateTime(today.year, today.month, today.day);
        final deadlineDay = DateTime(e.deadline!.year, e.deadline!.month, e.deadline!.day);
        return !selected.isBefore(todayDay) && !selected.isAfter(deadlineDay);
      }

      // Habits: Show only if selectedDate >= habit's startTime
      if (e.isHabit) {
        if (e.startTime == null) return true; // Fallback for old habits
        
        final habitStart = DateTime(e.startTime!.year, e.startTime!.month, e.startTime!.day);
        final selected = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
        
        // Show if selected date is same as or after habit start date
        return !selected.isBefore(habitStart);
      }

      // Filter by selected date (check if selectedDate is between startTime and endTime)
      if (e.startTime != null) {
        final start = DateTime(e.startTime!.year, e.startTime!.month, e.startTime!.day);
        final selected = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
        
        if (e.endTime != null) {
          final end = DateTime(e.endTime!.year, e.endTime!.month, e.endTime!.day);
          // selected >= start AND selected <= end
          return !selected.isBefore(start) && !selected.isAfter(end);
        } else {
          return selected.isAtSameMomentAs(start);
        }
      }
      
      // Unscheduled events: Keep visible? Or hide if not today?
      // For now, let's include them always so they are not lost.
      return true; 
    }).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const DateStripWidget(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.today),
                    tooltip: '回到今天',
                    onPressed: () {
                      final now = DateTime.now();
                      ref.read(selectedDateProvider.notifier).state = DateTime(
                        now.year,
                        now.month,
                        now.day,
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.calendar_month),
                    tooltip: '打开日历',
                    onPressed: () => _showDatePicker(context, ref, selectedDate),
                  ),
                  IconButton(
                    icon: const Icon(Icons.notifications_none),
                    tooltip: '提醒设置',
                    onPressed: () => _showReminderSettingsDialog(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _showAddEventDialog(context, ref),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _QuadrantCell(
                      title: '重要且紧急',
                      color: isDark ? _darkQuadrantRed : Colors.red[100]!,
                      events: quadrantEvents
                          .where((e) => e.isImportant && e.isUrgent)
                          .toList(),
                    ),
                  ),
                  Expanded(
                    child: _QuadrantCell(
                      title: '重要不紧急',
                      color: isDark ? _darkQuadrantBlue : Colors.blue[100]!,
                      events: quadrantEvents
                          .where((e) => e.isImportant && !e.isUrgent)
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _QuadrantCell(
                      title: '紧急不重要',
                      color: isDark ? _darkQuadrantYellow : Colors.yellow[100]!,
                      events: quadrantEvents
                          .where((e) => !e.isImportant && e.isUrgent)
                          .toList(),
                    ),
                  ),
                  Expanded(
                    child: _QuadrantCell(
                      title: '不重要不紧急',
                      color: isDark ? _darkQuadrantGrey : Colors.grey[300]!,
                      events: quadrantEvents
                          .where((e) => !e.isImportant && !e.isUrgent)
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddEventDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const AddEventDialog(),
    );
  }

  void _showReminderSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _ReminderSettingsDialog(),
    );
  }

  Future<void> _showDatePicker(
    BuildContext context,
    WidgetRef ref,
    DateTime selectedDate,
  ) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('zh', 'CN'),
    );

    if (pickedDate != null) {
      ref.read(selectedDateProvider.notifier).state = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
      );
    }
  }
}

class _ReminderSettingsDialog extends ConsumerWidget {
  const _ReminderSettingsDialog();

  static const List<int> _minuteOptions = [5, 10, 15, 30, 45, 60, 90, 120];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(reminderSettingsProvider);
    final notifier = ref.read(reminderSettingsProvider.notifier);

    return AlertDialog(
      title: const Text('提醒设置'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildRuleRow(
                context: context,
                title: '重要且紧急',
                rule: settings.rules[QuadrantType.importantUrgent]!,
                onSwitchChanged: (value) => notifier.updateEnabled(QuadrantType.importantUrgent, value),
                onMinutesChanged: (value) => notifier.updateMinutesBefore(QuadrantType.importantUrgent, value),
              ),
              _buildRuleRow(
                context: context,
                title: '重要不紧急',
                rule: settings.rules[QuadrantType.importantNotUrgent]!,
                onSwitchChanged: (value) => notifier.updateEnabled(QuadrantType.importantNotUrgent, value),
                onMinutesChanged: (value) => notifier.updateMinutesBefore(QuadrantType.importantNotUrgent, value),
              ),
              _buildRuleRow(
                context: context,
                title: '紧急不重要',
                rule: settings.rules[QuadrantType.urgentNotImportant]!,
                onSwitchChanged: (value) => notifier.updateEnabled(QuadrantType.urgentNotImportant, value),
                onMinutesChanged: (value) => notifier.updateMinutesBefore(QuadrantType.urgentNotImportant, value),
              ),
              _buildRuleRow(
                context: context,
                title: '不重要不紧急',
                rule: settings.rules[QuadrantType.notImportantNotUrgent]!,
                onSwitchChanged: (value) => notifier.updateEnabled(QuadrantType.notImportantNotUrgent, value),
                onMinutesChanged: (value) => notifier.updateMinutesBefore(QuadrantType.notImportantNotUrgent, value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  Widget _buildRuleRow({
    required BuildContext context,
    required String title,
    required ReminderRule rule,
    required ValueChanged<bool> onSwitchChanged,
    required ValueChanged<int> onMinutesChanged,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Switch(
                  value: rule.enabled,
                  onChanged: onSwitchChanged,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Text('提前'),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: rule.minutesBefore,
                  onChanged: rule.enabled
                      ? (value) {
                          if (value != null) {
                            onMinutesChanged(value);
                          }
                        }
                      : null,
                  items: _minuteOptions
                      .map(
                        (minute) => DropdownMenuItem<int>(
                          value: minute,
                          child: Text('$minute 分钟'),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(width: 8),
                const Text('提醒'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuadrantCell extends ConsumerStatefulWidget {
  final String title;
  final Color color;
  final List<PlanEvent> events;

  const _QuadrantCell({
    required this.title,
    required this.color,
    required this.events,
  });

  @override
  ConsumerState<_QuadrantCell> createState() => _QuadrantCellState();
}

class _QuadrantCellState extends ConsumerState<_QuadrantCell> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine the quadrant properties based on the title
    final bool isImportant = widget.title.startsWith('重要');
    final bool isUrgent = !widget.title.contains('不紧急');

    // Sort events:
    // 1. Uncompleted tasks first, completed tasks last
    // 2. Unscheduled events (startTime == null)
    // 3. Then by startTime (nearest first)
    // 4. Then by sortOrder
    final sortedEvents = List<PlanEvent>.from(widget.events);
    sortedEvents.sort((a, b) {
      // Completed events go to the bottom
      if (a.isCompleted && !b.isCompleted) return 1;
      if (!a.isCompleted && b.isCompleted) return -1;

      if (a.sortOrder != b.sortOrder) {
        return a.sortOrder.compareTo(b.sortOrder);
      }
      
      // If sortOrder is same (e.g. 0), sort by date
      if (a.startTime == null && b.startTime == null) return 0;
      if (a.startTime == null) return -1; // Unscheduled first
      if (b.startTime == null) return 1;
      
      return a.startTime!.compareTo(b.startTime!);
    });

    return DragTarget<PlanEvent>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        // Update the event's importance and urgency
        final updatedEvent = details.data.copyWith(
          isImportant: isImportant,
          isUrgent: isUrgent,
          sortOrder: 0, // Reset manual order when changing quadrant
        );
        ref.read(planEventsProvider.notifier).updateEvent(updatedEvent);
      },
      builder: (context, candidateData, rejectedData) {
        final scheme = Theme.of(context).colorScheme;
        
        return Container(
          margin: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: candidateData.isNotEmpty ? widget.color.withValues(alpha: 0.85) : widget.color.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isImportant && isUrgent ? Icons.warning_amber_rounded :
                      isImportant && !isUrgent ? Icons.star_border_rounded :
                      !isImportant && isUrgent ? Icons.bolt_rounded :
                      Icons.coffee_rounded,
                      size: 16,
                      color: scheme.onSurface.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: 0.5,
                        color: scheme.onSurface.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: sortedEvents.length + 1, // +1 for the bottom drop area
                    itemBuilder: (context, index) {
                      if (index == sortedEvents.length) {
                        // Empty space at the bottom to drop
                        return DragTarget<PlanEvent>(
                          onWillAcceptWithDetails: (details) => true,
                          onAcceptWithDetails: (details) {
                            // Move to this quadrant (append to end)
                            final updatedEvent = details.data.copyWith(
                              isImportant: isImportant,
                              isUrgent: isUrgent,
                              sortOrder: sortedEvents.length, // Put at end
                            );
                            ref.read(planEventsProvider.notifier).updateEvent(updatedEvent);
                          },
                          builder: (context, candidateData, rejectedData) {
                            return Container(
                              height: 50,
                              alignment: Alignment.center,
                              color: candidateData.isNotEmpty
                                  ? scheme.surfaceContainerHighest.withValues(alpha: 0.35)
                                  : Colors.transparent,
                              child: candidateData.isNotEmpty 
                                ? const Text("拖拽至此添加") 
                                : const SizedBox(),
                            );
                          },
                        );
                      }

                      final event = sortedEvents[index];
                      
                      // Check for date-specific exceptions for habits
                      DateTime? displayStartTime = event.startTime;
                      DateTime? displayEndTime = event.endTime;
                      final selectedDate = ref.watch(selectedDateProvider);
                      final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
                      
                      if (event.isHabit && event.habitExceptions != null && event.habitExceptions!.containsKey(dateStr)) {
                        displayStartTime = event.habitExceptions![dateStr]?['startTime'];
                        displayEndTime = event.habitExceptions![dateStr]?['endTime'];
                      } else if (event.isCountdown && event.deadline != null) {
                        if (event.habitExceptions != null && event.habitExceptions!.containsKey(dateStr)) {
                          displayStartTime = event.habitExceptions![dateStr]?['startTime'];
                          displayEndTime = event.habitExceptions![dateStr]?['endTime'];
                        } else {
                          displayStartTime = DateTime(
                            selectedDate.year,
                            selectedDate.month,
                            selectedDate.day,
                            event.deadline!.hour,
                            event.deadline!.minute,
                          );
                          displayEndTime = displayStartTime.add(const Duration(hours: 1));
                        }
                      } else if (event.isHabit) {
                        if (displayStartTime != null) {
                          displayStartTime = DateTime(
                            selectedDate.year,
                            selectedDate.month,
                            selectedDate.day,
                            displayStartTime.hour,
                            displayStartTime.minute,
                          );
                        }
                        if (displayEndTime != null) {
                          displayEndTime = DateTime(
                            selectedDate.year,
                            selectedDate.month,
                            selectedDate.day,
                            displayEndTime.hour,
                            displayEndTime.minute,
                          );
                          if (displayStartTime != null && displayEndTime.isBefore(displayStartTime)) {
                            displayEndTime = displayEndTime.add(const Duration(days: 1));
                          }
                        }
                      }
                      
                      String timeRange;
                      if (event.isCountdown && event.deadline != null) {
                        final planText = (displayStartTime != null && displayEndTime != null)
                            ? '${DateFormat('HH:mm').format(displayStartTime)} - ${DateFormat('HH:mm').format(displayEndTime)}'
                            : '未安排';
                        timeRange = '截止: ${DateFormat('MM-dd HH:mm').format(event.deadline!)}\n今日计划: $planText';
                      } else {
                        final timeFormat = DateFormat('MM-dd HH:mm');
                        final startTimeStr = displayStartTime != null ? timeFormat.format(displayStartTime) : '';
                        final endTimeStr = displayEndTime != null ? timeFormat.format(displayEndTime) : '';
                        timeRange = (startTimeStr.isNotEmpty && endTimeStr.isNotEmpty)
                            ? '$startTimeStr - $endTimeStr'
                            : startTimeStr;
                      }

                      // Each Item is a Drop Target (for Reordering/Insertion)
                      return DragTarget<PlanEvent>(
                        onWillAcceptWithDetails: (details) => details.data.id != event.id,
                        onAcceptWithDetails: (details) {
                          final incomingEvent = details.data;
                          // Insert 'incomingEvent' at 'index'
                          // Shift items down?
                          // We need to re-index.
                          
                          // 1. Remove incomingEvent from old list (handled by provider update implicitly)
                          // 2. Insert into this list at index
                          
                          // Logic:
                          // Set incomingEvent.sortOrder = index
                          // Shift current item and subsequent items down (sortOrder + 1)
                          
                          // This is complex to do transactionally.
                          // Simple approach: 
                          // Just set incomingEvent.sortOrder = index.
                          // But if there's already an item at index, collision?
                          // Sort logic handles it (stable sort).
                          // Better: Set incomingEvent.sortOrder = index - 0.5 (if inserting before)
                          // But sortOrder is int.
                          
                          // Let's re-calculate sortOrder for ALL items in this quadrant.
                          final newOrderList = List<PlanEvent>.from(sortedEvents);
                          
                          // If incomingEvent is already in list, move it.
                          final existingIndex = newOrderList.indexWhere((e) => e.id == incomingEvent.id);
                          if (existingIndex != -1) {
                            newOrderList.removeAt(existingIndex);
                          }
                          
                          // Insert at target index
                          // If we dragged from above, and removed, index might shift.
                          // Just insert at `index` (clamped).
                          int targetIndex = index;
                          if (existingIndex != -1 && existingIndex < targetIndex) {
                            targetIndex -= 1;
                          }
                          
                          newOrderList.insert(targetIndex.clamp(0, newOrderList.length), incomingEvent);
                          
                          // Update all sortOrders
                          for (int i = 0; i < newOrderList.length; i++) {
                            final e = newOrderList[i];
                            // Update both quadrant AND order
                            if (e.id == incomingEvent.id || e.sortOrder != i) {
                               final updated = e.copyWith(
                                 isImportant: isImportant,
                                 isUrgent: isUrgent,
                                 sortOrder: i,
                               );
                               ref.read(planEventsProvider.notifier).updateEvent(updated);
                            }
                          }
                        },
                        builder: (context, candidateData, rejectedData) {
                          return Column(
                            children: [
                              // Visual indicator for insertion point (Top)
                              if (candidateData.isNotEmpty)
                                Container(height: 2, color: scheme.primary),
                                
                              LongPressDraggable<PlanEvent>(
                                data: event,
                                feedback: SizedBox(
                                  width: 200,
                                  child: Card(
                                    color: scheme.surface.withValues(alpha: 0.9),
                                    elevation: 4,
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        event.title,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ),
                                childWhenDragging: Opacity(
                                  opacity: 0.5,
                                  child: _buildEventCard(event, timeRange),
                                ),
                                child: _buildEventCard(event, timeRange),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditEventDialog(BuildContext context, PlanEvent event) {
    final titleController = TextEditingController(text: event.title);
    final locationController = TextEditingController(text: event.location);
    bool isImportant = event.isImportant;
    bool isUrgent = event.isUrgent;
    
    // Get current selected date to handle habit exceptions
    final selectedDate = ref.read(selectedDateProvider);
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    
    DateTime? startTime = event.startTime;
    DateTime? endTime = event.endTime;
    
    if (event.isHabit && event.habitExceptions != null && event.habitExceptions!.containsKey(dateStr)) {
      startTime = event.habitExceptions![dateStr]?['startTime'];
      endTime = event.habitExceptions![dateStr]?['endTime'];
    } else if (event.isCountdown && event.deadline != null) {
      if (event.habitExceptions != null && event.habitExceptions!.containsKey(dateStr)) {
        startTime = event.habitExceptions![dateStr]?['startTime'];
        endTime = event.habitExceptions![dateStr]?['endTime'];
      } else {
        startTime = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          event.deadline!.hour,
          event.deadline!.minute,
        );
        endTime = startTime.add(const Duration(hours: 1));
      }
    } else if (event.isHabit) {
      if (startTime != null) {
        startTime = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          startTime.hour,
          startTime.minute,
        );
      }
      if (endTime != null) {
        endTime = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          endTime.hour,
          endTime.minute,
        );
        if (startTime != null && endTime.isBefore(startTime)) {
          endTime = endTime.add(const Duration(days: 1));
        }
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('编辑任务'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: '任务标题'),
                    ),
                    TextField(
                      controller: locationController,
                      decoration: const InputDecoration(labelText: '地点'),
                    ),
                    if (event.isCountdown && event.deadline != null) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('截止时间: ${DateFormat('MM-dd HH:mm').format(event.deadline!)}'),
                      ),
                    ],
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: const Text('重要'),
                      value: isImportant,
                      onChanged: (val) => setState(() => isImportant = val!),
                    ),
                    CheckboxListTile(
                      title: const Text('紧急'),
                      value: isUrgent,
                      onChanged: (val) => setState(() => isUrgent = val!),
                    ),
                    ListTile(
                      title: Text(startTime == null
                          ? (event.isCountdown ? '今日计划开始时间' : '开始时间')
                          : (event.isCountdown
                              ? '今日计划开始: ${DateFormat('MM-dd HH:mm').format(startTime!)}'
                              : '开始: ${DateFormat('MM-dd HH:mm').format(startTime!)}')),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        if (event.isCountdown) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(startTime ?? DateTime.now()),
                          );
                          if (time != null) {
                            setState(() {
                              startTime = DateTime(
                                selectedDate.year,
                                selectedDate.month,
                                selectedDate.day,
                                time.hour,
                                time.minute,
                              );
                              if (endTime == null || endTime!.isBefore(startTime!)) {
                                endTime = startTime!.add(const Duration(hours: 1));
                              }
                            });
                          }
                          return;
                        }
                        final date = await showDatePicker(
                          context: context,
                          initialDate: startTime ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (date != null && context.mounted) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(startTime ?? DateTime.now()),
                          );
                          if (time != null) {
                            setState(() {
                              startTime = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                time.hour,
                                time.minute,
                              );
                              // Auto-set end time if not set or invalid
                              if (endTime == null || endTime!.isBefore(startTime!)) {
                                endTime = startTime!.add(const Duration(hours: 1));
                              }
                            });
                          }
                        }
                      },
                    ),
                    ListTile(
                      title: Text(endTime == null
                          ? (event.isCountdown ? '今日计划结束时间' : '结束时间')
                          : (event.isCountdown
                              ? '今日计划结束: ${DateFormat('MM-dd HH:mm').format(endTime!)}'
                              : '结束: ${DateFormat('MM-dd HH:mm').format(endTime!)}')),
                      trailing: const Icon(Icons.access_time_filled),
                      onTap: () async {
                        if (event.isCountdown) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(endTime ?? startTime ?? DateTime.now()),
                          );
                          if (time != null) {
                            setState(() {
                              endTime = DateTime(
                                selectedDate.year,
                                selectedDate.month,
                                selectedDate.day,
                                time.hour,
                                time.minute,
                              );
                            });
                          }
                          return;
                        }
                        final initialEnd = endTime ?? (startTime?.add(const Duration(hours: 1)) ?? DateTime.now().add(const Duration(hours: 1)));
                        final date = await showDatePicker(
                          context: context,
                          initialDate: initialEnd,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (date != null && context.mounted) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(initialEnd),
                          );
                          if (time != null) {
                            setState(() {
                              endTime = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                time.hour,
                                time.minute,
                              );
                            });
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    // Confirm delete
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('删除任务'),
                        content: const Text('确定要删除这个任务吗？'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                          TextButton(
                            onPressed: () {
                              ref.read(planEventsProvider.notifier).deleteEvent(event);
                              Navigator.pop(ctx); // Close confirmation dialog
                              Navigator.pop(context); // Close edit dialog
                            },
                            child: const Text('删除', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('删除', style: TextStyle(color: Colors.red)),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (titleController.text.isNotEmpty) {
                      PlanEvent updatedEvent;
                      
                      if (event.isHabit || event.isCountdown) {
                        // For habits, only update the exception for the currently selected date
                        // Do not modify the base habit's default start/end time
                        final exceptions = Map<String, Map<String, DateTime?>>.from(event.habitExceptions ?? {});
                        exceptions[dateStr] = {
                          'startTime': startTime,
                          'endTime': endTime,
                        };
                        
                        updatedEvent = event.copyWith(
                          title: titleController.text,
                          location: locationController.text,
                          isImportant: isImportant,
                          isUrgent: isUrgent,
                          habitExceptions: exceptions,
                        );
                      } else {
                        // For normal events, update directly
                        updatedEvent = event.copyWith(
                          title: titleController.text,
                          location: locationController.text,
                          isImportant: isImportant,
                          isUrgent: isUrgent,
                          startTime: startTime,
                          endTime: endTime,
                        );
                      }
                      
                      ref.read(planEventsProvider.notifier).updateEvent(updatedEvent);
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  Widget _buildEventCard(PlanEvent event, String timeRange) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: isDark ? 0 : 2,
      shadowColor: Colors.black.withValues(alpha: 0.04),
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isDark 
            ? BorderSide(color: scheme.outline.withValues(alpha: 0.15)) 
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Row
            Row(
              children: [
                SizedBox(
                  height: 24,
                  width: 24,
                  child: Checkbox(
                    value: event.isCompleted,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    side: BorderSide(color: scheme.outline.withValues(alpha: 0.4), width: 1.5),
                    onChanged: (val) {
                      // Toggle complete status
                      ref.read(planEventsProvider.notifier).toggleComplete(event);
                    },
                    activeColor: scheme.primary, // Green for complete
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () => _showEditEventDialog(context, event),
                    child: Text(
                      event.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: event.isCompleted ? scheme.onSurface.withValues(alpha: 0.4) : scheme.onSurface.withValues(alpha: 0.9),
                        decoration: event.isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                ),
                // Edit Button (Icon)
                SizedBox(
                  height: 24,
                  width: 24,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.edit, size: 18, color: scheme.secondary),
                    onPressed: () => _showEditEventDialog(context, event),
                    tooltip: '编辑',
                  ),
                ),
              ],
            ),
            // Time Row
            if (timeRange.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: scheme.outline),
                  const SizedBox(width: 4),
                  Text(
                    timeRange,
                    style: TextStyle(fontSize: 12, color: scheme.outline),
                  ),
                ],
              ),
            ],
            // Location Row
            if (event.location != null && event.location!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: scheme.outline),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      event.location!,
                      style: TextStyle(fontSize: 12, color: scheme.outline),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AddEventDialog extends ConsumerStatefulWidget {
  const AddEventDialog({super.key});

  @override
  ConsumerState<AddEventDialog> createState() => _AddEventDialogState();
}

class _AddEventDialogState extends ConsumerState<AddEventDialog> {
  final _titleController = TextEditingController();
  bool _isImportant = false;
  bool _isUrgent = false;
  DateTime? _startTime;
  DateTime? _endTime;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加新任务'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: '任务标题'),
            ),
            CheckboxListTile(
              title: const Text('重要'),
              value: _isImportant,
              onChanged: (val) => setState(() => _isImportant = val!),
            ),
            CheckboxListTile(
              title: const Text('紧急'),
              value: _isUrgent,
              onChanged: (val) => setState(() => _isUrgent = val!),
            ),
            ListTile(
              title: Text(_startTime == null ? '开始时间 (可选)' : '开始: ${DateFormat('MM-dd HH:mm').format(_startTime!)}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _startTime ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (date != null && context.mounted) {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(_startTime ?? DateTime.now()),
                  );
                  if (time != null) {
                    setState(() {
                      _startTime = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        time.hour,
                        time.minute,
                      );
                      // Auto-set end time if not set or invalid
                      if (_endTime == null || _endTime!.isBefore(_startTime!)) {
                        _endTime = _startTime!.add(const Duration(hours: 1));
                      }
                    });
                  }
                }
              },
            ),
            ListTile(
              title: Text(_endTime == null ? '结束时间 (可选)' : '结束: ${DateFormat('MM-dd HH:mm').format(_endTime!)}'),
              trailing: const Icon(Icons.access_time_filled),
              onTap: () async {
                final initialEnd = _endTime ?? (_startTime?.add(const Duration(hours: 1)) ?? DateTime.now().add(const Duration(hours: 1)));
                final date = await showDatePicker(
                  context: context,
                  initialDate: initialEnd,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (date != null && context.mounted) {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(initialEnd),
                  );
                  if (time != null) {
                    setState(() {
                      _endTime = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        time.hour,
                        time.minute,
                      );
                      // If only end time is set, default start time to 1 hour before
                      if (_startTime == null) {
                        _startTime = _endTime!.subtract(const Duration(hours: 1));
                      } else if (_startTime!.isAfter(_endTime!)) {
                        // Or if end time is now before start time, adjust start time
                        _startTime = _endTime!.subtract(const Duration(hours: 1));
                      }
                    });
                  }
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_titleController.text.isNotEmpty) {
              DateTime? finalStartTime = _startTime;
              DateTime? finalEndTime = _endTime;
              
              // If user didn't set time, default to 00:00 of the currently selected date
              if (finalStartTime == null) {
                final selectedDate = ref.read(selectedDateProvider);
                finalStartTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 0, 0);
                finalEndTime = finalStartTime.add(const Duration(hours: 1));
              }

              final newEvent = PlanEvent(
                title: _titleController.text,
                isImportant: _isImportant,
                isUrgent: _isUrgent,
                startTime: finalStartTime,
                endTime: finalEndTime,
              );
              ref.read(planEventsProvider.notifier).addEvent(newEvent);
              Navigator.pop(context);
            }
          },
          child: const Text('添加'),
        ),
      ],
    );
  }
}
