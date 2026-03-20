import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_time_manager/models/plan_event.dart';
import 'package:smart_time_manager/providers/plan_provider.dart';
import 'package:smart_time_manager/providers/selected_date_provider.dart';
import 'package:intl/intl.dart';
import 'package:smart_time_manager/widgets/date_strip_widget.dart';

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  // Date strip logic moved to DateStripWidget
  static const Color _darkQuadrantRed = Color(0xFF5A1E1E);
  static const Color _darkQuadrantBlue = Color(0xFF1E3F66);
  static const Color _darkQuadrantYellow = Color(0xFF5B4A14);
  static const Color _darkQuadrantGrey = Color(0xFF35393F);

  Color _getEventColor(BuildContext context, PlanEvent event) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (event.isImportant && event.isUrgent) {
      return isDark ? _darkQuadrantRed : Colors.red[100]!;
    } else if (event.isImportant && !event.isUrgent) {
      return isDark ? _darkQuadrantBlue : Colors.blue[100]!;
    } else if (!event.isImportant && event.isUrgent) {
      return isDark ? _darkQuadrantYellow : Colors.yellow[100]!;
    } else {
      return isDark ? _darkQuadrantGrey : Colors.grey[300]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final allEvents = ref.watch(planEventsProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final scheme = Theme.of(context).colorScheme;
    
    final timelineEvents = allEvents.where((e) {
      if (e.startTime == null && !(e.isCountdown && e.deadline != null)) return false;
      // Filter out completed tasks
      if (e.isCompleted) return false;
      
      final selected = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
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
    timelineEvents.sort((a, b) {
      final aTime = a.startTime ?? a.deadline ?? DateTime.now();
      final bTime = b.startTime ?? b.deadline ?? DateTime.now();
      return aTime.compareTo(bTime);
    });

    // Unscheduled events for the drawer
    final unscheduledEvents = allEvents.where((e) => e.startTime == null && !e.isCountdown).toList();

    const double hourHeight = 80.0;
    const double timeColumnWidth = 60.0;

    return Scaffold(
      endDrawer: Drawer(
        width: 300,
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.55),
              ),
              child: Center(
                child: Text(
                  '待办任务池',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: scheme.onPrimaryContainer),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: unscheduledEvents.length,
                itemBuilder: (context, index) {
                  final event = unscheduledEvents[index];
                  return Draggable<PlanEvent>(
                    data: event,
                    feedback: SizedBox(
                      width: 250,
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: scheme.outline.withValues(alpha: 0.2)),
                        ),
                        color: _getEventColor(context, event).withValues(alpha: 0.9),
                        child: ListTile(title: Text(event.title)),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.5,
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: scheme.outline.withValues(alpha: 0.16)),
                        ),
                        child: ListTile(title: Text(event.title)),
                      ),
                    ),
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: scheme.outline.withValues(alpha: 0.2)),
                      ),
                      color: _getEventColor(context, event),
                      child: ListTile(title: Text(event.title)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
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
                    onPressed: () async {
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
                    },
                  ),
                  Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.list_alt),
                      tooltip: '待办任务池',
                      onPressed: () => Scaffold.of(context).openEndDrawer(),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
              child: SizedBox(
                height: 24 * hourHeight,
                child: Stack(
                  children: [
                    // 1. Background Grid and Time Labels
                    for (int hour = 0; hour < 24; hour++)
                      Positioned(
                        top: hour * hourHeight,
                        left: 0,
                        right: 0,
                        height: hourHeight,
                        child: DragTarget<PlanEvent>(
                          onWillAcceptWithDetails: (details) => true,
                          onAcceptWithDetails: (details) {
                            final event = details.data;
                            // When dropped, snap to the hour
                            final newStartTime = DateTime(
                              selectedDate.year, 
                              selectedDate.month, 
                              selectedDate.day, 
                              hour, 
                              0,
                            );
                            
                            // Preserve duration if it had one, otherwise default to 1 hour
                            Duration duration = const Duration(hours: 1);
                            if (event.startTime != null && event.endTime != null) {
                              duration = event.endTime!.difference(event.startTime!);
                            }
                            
                            final newEndTime = newStartTime.add(duration);
                            
                            final updatedEvent = event.copyWith(
                              startTime: newStartTime,
                              endTime: newEndTime,
                            );
                            ref.read(planEventsProvider.notifier).updateEvent(updatedEvent);
                          },
                          builder: (context, candidateData, rejectedData) {
                            return Container(
                              color: candidateData.isNotEmpty
                                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                                  : null,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: timeColumnWidth,
                                    child: Transform.translate(
                                      offset: const Offset(0, -8), // Shift text up slightly so it aligns with the line
                                      child: Text(
                                        '${hour.toString().padLeft(2, '0')}:00',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 1,
                                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                                  ),
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border(
                                          top: BorderSide(
                                            color: scheme.outlineVariant.withValues(alpha: 0.5),
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                    // 2. Events overlay
                    ...timelineEvents.map((event) {
                      final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
                      DateTime? displayStartTime = event.startTime;
                      DateTime? displayEndTime = event.endTime;

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

                      // Calculate effective start and end hours for THIS specific date
                      final selected = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
                      final startBase = displayStartTime ?? event.startTime!;
                      final start = DateTime(startBase.year, startBase.month, startBase.day);
                      
                      double startHour = 0.0;
                      if (start.isAtSameMomentAs(selected)) {
                        startHour = startBase.hour + (startBase.minute / 60.0);
                      } // else it started on a previous day, so it starts at 00:00 today
                      
                      double endHour = startHour + 1.0; // Default 1 hour duration
                      if (displayEndTime != null) {
                        final end = DateTime(displayEndTime.year, displayEndTime.month, displayEndTime.day);
                        if (end.isAtSameMomentAs(selected)) {
                          endHour = displayEndTime.hour + (displayEndTime.minute / 60.0);
                        } else if (end.isAfter(selected)) {
                          endHour = 24.0; // Ends on a future day, so it goes until midnight today
                        }
                      }
                      
                      // Calculate positions
                      final top = startHour * hourHeight;
                      final height = (endHour - startHour) * hourHeight;
                      
                      // Format time string
                      String timeRange;
                      if (event.isCountdown && event.deadline != null) {
                        final planText = (displayStartTime != null && displayEndTime != null)
                            ? '${DateFormat('HH:mm').format(displayStartTime)} - ${DateFormat('HH:mm').format(displayEndTime)}'
                            : '未安排';
                        timeRange = '截止 ${DateFormat('MM-dd HH:mm').format(event.deadline!)}\n今日计划: $planText';
                      } else {
                        final timeFormat = DateFormat('HH:mm');
                        final startTimeStr = timeFormat.format(startBase);
                        final endTimeStr = displayEndTime != null ? timeFormat.format(displayEndTime) : '';
                        timeRange = endTimeStr.isNotEmpty ? '$startTimeStr - $endTimeStr' : startTimeStr;
                      }
                      final compactCountdown = event.isCountdown && event.deadline != null && height < 64;
                      final detailText = compactCountdown
                          ? '截止 ${DateFormat('MM-dd HH:mm').format(event.deadline!)}'
                          : timeRange;
                      final detailMaxLines = (event.isCountdown && !compactCountdown) ? 2 : 1;

                      return Positioned(
                        top: top,
                        left: timeColumnWidth + 1, // Start after the vertical divider
                        right: 12, // Add some padding on the right
                        height: height,
                        child: Container(
                          margin: const EdgeInsets.only(left: 6, top: 2, bottom: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getEventColor(context, event).withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event.title,
                                style: TextStyle(
                                  fontSize: 13, 
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (height >= 40)
                                const SizedBox(height: 4),
                              if (height >= 40)
                                Expanded(
                                  child: Text(
                                    detailText,
                                    maxLines: detailMaxLines,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
