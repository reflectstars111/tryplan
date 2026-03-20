import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_time_manager/models/plan_event.dart';
import 'package:smart_time_manager/providers/plan_provider.dart';
import 'package:smart_time_manager/providers/selected_date_provider.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:intl/intl.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  static const Color _darkQuadrantRed = Color(0xFF5A1E1E);
  static const Color _darkQuadrantBlue = Color(0xFF1E3F66);
  static const Color _darkQuadrantYellow = Color(0xFF5B4A14);
  static const Color _darkQuadrantGrey = Color(0xFF35393F);

  @override
  void initState() {
    super.initState();
    // Sync initial focused day with provider
    _focusedDay = ref.read(selectedDateProvider);
  }

  Color _getEventColor(BuildContext context, PlanEvent event) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (event.isImportant && event.isUrgent) {
      return isDark ? _darkQuadrantRed : Colors.red;
    } else if (event.isImportant && !event.isUrgent) {
      return isDark ? _darkQuadrantBlue : Colors.blue;
    } else if (!event.isImportant && event.isUrgent) {
      return isDark ? _darkQuadrantYellow : Colors.amber;
    } else {
      return isDark ? _darkQuadrantGrey : Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final allEvents = ref.watch(planEventsProvider);
    final selectedDay = ref.watch(selectedDateProvider);
    final scheme = Theme.of(context).colorScheme;
    final scheduledEvents =
        allEvents.where((e) => e.startTime != null || (e.isCountdown && e.deadline != null)).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '日历视图',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Card(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              elevation: 0,
              clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: scheme.outline.withValues(alpha: 0.16)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: TableCalendar(
                locale: 'zh_CN',
                firstDay: DateTime.utc(2020, 10, 16),
                lastDay: DateTime.utc(2030, 3, 14),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                selectedDayPredicate: (day) {
                  return isSameDay(selectedDay, day);
                },
                headerStyle: HeaderStyle(
                  titleCentered: true,
                  formatButtonDecoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  formatButtonTextStyle: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                  weekendStyle: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600),
                ),
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: BoxDecoration(
                    color: scheme.tertiary,
                    shape: BoxShape.circle,
                  ),
                  outsideTextStyle: TextStyle(color: scheme.outline),
                ),
                onDaySelected: (selected, focused) {
                  if (!isSameDay(selectedDay, selected)) {
                    ref.read(selectedDateProvider.notifier).state = DateTime(
                      selected.year,
                      selected.month,
                      selected.day,
                    );
                    setState(() {
                      _focusedDay = focused;
                    });
                  }
                },
                onFormatChanged: (format) {
                  if (_calendarFormat != format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  }
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
                eventLoader: (day) {
                  return scheduledEvents
                      .where((e) {
                        if (e.startTime == null) return false;
                        if (e.isHabit) {
                          final habitStart = DateTime(e.startTime!.year, e.startTime!.month, e.startTime!.day);
                          final targetDay = DateTime(day.year, day.month, day.day);
                          return !targetDay.isBefore(habitStart);
                        }
                        if (e.isCountdown && e.deadline != null) {
                          final targetDay = DateTime(day.year, day.month, day.day);
                          final now = DateTime.now();
                          final today = DateTime(now.year, now.month, now.day);
                          final deadlineDay = DateTime(e.deadline!.year, e.deadline!.month, e.deadline!.day);
                          return !targetDay.isBefore(today) && !targetDay.isAfter(deadlineDay);
                        }
                        return isSameDay(e.startTime, day);
                      })
                      .toList();
                },
              ),
            ),
          ),
          const SizedBox(height: 8.0),
          Expanded(
            child: _buildEventList(scheduledEvents, selectedDay),
          ),
        ],
      ),
      ),
    );
  }

  void _showEditEventDialog(BuildContext context, PlanEvent event) {
    final titleController = TextEditingController(text: event.title);
    final locationController = TextEditingController(text: event.location);
    bool isImportant = event.isImportant;
    bool isUrgent = event.isUrgent;
    final selectedDate = ref.read(selectedDateProvider);
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    DateTime? startTime = event.startTime;
    DateTime? endTime = event.endTime;

    if (event.isCountdown && event.deadline != null) {
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
                      if (event.isCountdown) {
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

  Widget _buildEventList(List<PlanEvent> events, DateTime selectedDay) {
    // Only show active (uncompleted) tasks
    final selectedEvents = events.where((e) {
      if (e.isCompleted) return false;
      if (e.startTime == null && !e.isCountdown) return false;

      final selected = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      if (e.isCountdown && e.deadline != null) {
        final deadlineDay = DateTime(e.deadline!.year, e.deadline!.month, e.deadline!.day);
        return !selected.isBefore(today) && !selected.isAfter(deadlineDay);
      }

      final start = DateTime(e.startTime!.year, e.startTime!.month, e.startTime!.day);

      if (e.isHabit) {
        return !selected.isBefore(start);
      }

      if (e.endTime != null) {
        final end = DateTime(e.endTime!.year, e.endTime!.month, e.endTime!.day);
        return !selected.isBefore(start) && !selected.isAfter(end);
      } else {
        return selected.isAtSameMomentAs(start);
      }
    }).toList();

    if (selectedEvents.isEmpty) {
      return const Center(
        child: Text('该日无行程'),
      );
    }

    return ListView.builder(
      itemCount: selectedEvents.length,
      itemBuilder: (context, index) {
        final event = selectedEvents[index];
        final eventColor = _getEventColor(context, event);
        final dateStr = DateFormat('yyyy-MM-dd').format(selectedDay);
        DateTime? displayStartTime = event.startTime;
        DateTime? displayEndTime = event.endTime;

        if (event.isHabit && event.habitExceptions != null && event.habitExceptions!.containsKey(dateStr)) {
          displayStartTime = event.habitExceptions![dateStr]?['startTime'];
          displayEndTime = event.habitExceptions![dateStr]?['endTime'];
        } else if (event.isHabit) {
          if (displayStartTime != null) {
            displayStartTime = DateTime(
              selectedDay.year,
              selectedDay.month,
              selectedDay.day,
              displayStartTime.hour,
              displayStartTime.minute,
            );
          }
          if (displayEndTime != null) {
            displayEndTime = DateTime(
              selectedDay.year,
              selectedDay.month,
              selectedDay.day,
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
          if (event.habitExceptions != null && event.habitExceptions!.containsKey(dateStr)) {
            displayStartTime = event.habitExceptions![dateStr]?['startTime'];
            displayEndTime = event.habitExceptions![dateStr]?['endTime'];
          } else {
            displayStartTime = DateTime(
              selectedDay.year,
              selectedDay.month,
              selectedDay.day,
              event.deadline!.hour,
              event.deadline!.minute,
            );
            displayEndTime = displayStartTime.add(const Duration(hours: 1));
          }
          final planText = (displayStartTime != null && displayEndTime != null)
              ? '${DateFormat('HH:mm').format(displayStartTime)} - ${DateFormat('HH:mm').format(displayEndTime)}'
              : '未安排';
          timeRange = '截止: ${DateFormat('MM-dd HH:mm').format(event.deadline!)}\n今日计划: $planText';
        } else {
          final timeFormat = DateFormat('HH:mm');
          final startTime = displayStartTime != null ? timeFormat.format(displayStartTime) : '';
          final endTime = displayEndTime != null ? timeFormat.format(displayEndTime) : '';
          timeRange = endTime.isNotEmpty ? '$startTime - $endTime' : startTime;
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.16)),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Color Strip
                Container(
                  width: 6.0,
                  decoration: BoxDecoration(
                    color: eventColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4.0),
                      bottomLeft: Radius.circular(4.0),
                    ),
                  ),
                ),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0), // Reduced padding slightly to fit new elements
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title Row with Checkbox (Delete) and Edit Button
                        Row(
                          children: [
                            SizedBox(
                              height: 24,
                              width: 24,
                              child: Checkbox(
                                value: event.isCompleted,
                                activeColor: Theme.of(context).colorScheme.primary,
                                onChanged: (val) {
                                  if (val == true) {
                                    ref.read(planEventsProvider.notifier).toggleComplete(event);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: InkWell(
                                onTap: () => _showEditEventDialog(context, event),
                                child: Text(
                                  event.title,
                                  style: const TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              height: 24,
                              width: 24,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: Icon(Icons.edit, size: 18, color: Theme.of(context).colorScheme.secondary),
                                onPressed: () => _showEditEventDialog(context, event),
                                tooltip: '编辑',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4.0),
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 16.0, color: Theme.of(context).colorScheme.outline),
                            const SizedBox(width: 4.0),
                            Text(
                              timeRange,
                              style: TextStyle(color: Theme.of(context).colorScheme.outline),
                            ),
                          ],
                        ),
                        if (event.location != null && event.location!.isNotEmpty) ...[
                          const SizedBox(height: 4.0),
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 16.0, color: Theme.of(context).colorScheme.outline),
                              const SizedBox(width: 4.0),
                              Text(
                                event.location!,
                                style: TextStyle(color: Theme.of(context).colorScheme.outline),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
