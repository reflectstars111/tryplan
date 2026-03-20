import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_time_manager/models/plan_event.dart';
import 'package:smart_time_manager/providers/plan_provider.dart';
import 'package:intl/intl.dart';

class DatabaseScreen extends ConsumerStatefulWidget {
  const DatabaseScreen({super.key});

  @override
  ConsumerState<DatabaseScreen> createState() => _DatabaseScreenState();
}

class _DatabaseScreenState extends ConsumerState<DatabaseScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Text(
                    '数据统计',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: '已完成任务'),
                Tab(text: '长期计划打卡'),
                Tab(text: '倒计时'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  _CompletedTasksList(),
                  _HabitStreaksList(),
                  _CountdownList(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_tabController.index == 1) {
            _showAddHabitDialog(context, ref);
          } else if (_tabController.index == 2) {
            _showAddCountdownDialog(context, ref);
          } else {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text('只能在长期计划或倒计时页面添加')),
             );
          }
        },
        tooltip: '添加',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddCountdownDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    DateTime? selectedDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('添加倒计时'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: '事件名称',
                    hintText: '例如：完成作业、期末考试',
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: Text(selectedDate == null 
                      ? '选择截止时间' 
                      : '截止: ${DateFormat('yyyy-MM-dd HH:mm').format(selectedDate!)}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                    );
                    if (date != null && context.mounted) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: const TimeOfDay(hour: 0, minute: 0),
                      );
                      if (time != null) {
                        setState(() {
                          selectedDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                        });
                      }
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (titleController.text.isNotEmpty && selectedDate != null) {
                    final newCountdown = PlanEvent(
                      title: titleController.text,
                      isImportant: true,
                      isUrgent: false,
                      isCountdown: true,
                      deadline: selectedDate,
                    );
                    ref.read(planEventsProvider.notifier).addEvent(newCountdown);
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('请输入名称并选择截止日期')),
                    );
                  }
                },
                child: const Text('添加'),
              ),
            ],
          );
        }
      ),
    );
  }

  void _showAddHabitDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加长期计划'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(
            labelText: '计划名称',
            hintText: '例如：每天背单词、每周跑步',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                final now = DateTime.now();
                final newHabit = PlanEvent(
                  title: titleController.text,
                  startTime: DateTime(now.year, now.month, now.day), // Set start date to today (normalized)
                  isImportant: true, // Default to important
                  isUrgent: false,
                  isHabit: true,
                  streakDates: [],
                );
                ref.read(planEventsProvider.notifier).addEvent(newHabit);
                Navigator.pop(context);
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }
}

class _CompletedTasksList extends ConsumerWidget {
  const _CompletedTasksList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allEvents = ref.watch(planEventsProvider);
    // Filter completed tasks that are NOT habits
    final completedEvents = allEvents
        .where((e) => e.isCompleted && !e.isHabit)
        .toList();
    
    // Sort by completion time (if we had it) or creation time (id usually time-based UUID, but not guaranteed)
    // For now, reverse order to show newest added first
    final reversedList = completedEvents.reversed.toList();

    if (reversedList.isEmpty) {
      return const Center(child: Text('暂无已完成的任务'));
    }

    return ListView.builder(
      itemCount: reversedList.length,
      itemBuilder: (context, index) {
        final event = reversedList[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: const Icon(Icons.check_circle, color: Colors.green),
            title: Text(
              event.title,
              style: const TextStyle(decoration: TextDecoration.lineThrough),
            ),
            subtitle: event.startTime != null 
                ? Text('时间: ${DateFormat('MM-dd HH:mm').format(event.startTime!)}')
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.restore, color: Colors.blue),
                  tooltip: '还原任务',
                  onPressed: () {
                    // Toggle complete back to false to restore it to active tasks
                    ref.read(planEventsProvider.notifier).toggleComplete(event);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已还原到任务列表')),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: '永久删除',
                  onPressed: () {
                    // Confirm delete
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('删除记录'),
                        content: const Text('确定要永久删除这条已完成的记录吗？'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                          TextButton(
                            onPressed: () {
                              ref.read(planEventsProvider.notifier).deleteEvent(event);
                              Navigator.pop(ctx);
                            },
                            child: const Text('删除'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HabitStreaksList extends ConsumerWidget {
  const _HabitStreaksList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allEvents = ref.watch(planEventsProvider);
    final habits = allEvents.where((e) => e.isHabit).toList();

    if (habits.isEmpty) {
      return const Center(child: Text('暂无长期计划，点击右下角添加'));
    }

    return ListView.builder(
      itemCount: habits.length,
      itemBuilder: (context, index) {
        final habit = habits[index];
        final streakCount = habit.streakDates?.length ?? 0;
        final isCheckedToday = _isCheckedToday(habit);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        habit.title,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.edit, color: Theme.of(context).colorScheme.secondary, size: 20),
                      onPressed: () => _showEditHabitDialog(context, ref, habit),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.outline, size: 20),
                      onPressed: () => ref.read(planEventsProvider.notifier).deleteEvent(habit),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Chip(
                      label: Text('已坚持 $streakCount 天'),
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      avatar: Icon(Icons.local_fire_department, color: Theme.of(context).colorScheme.tertiary, size: 18),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      icon: Icon(isCheckedToday ? Icons.check : Icons.touch_app),
                      label: Text(isCheckedToday ? '今日已打卡' : '打卡'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isCheckedToday
                            ? Theme.of(context).colorScheme.secondary
                            : Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                      onPressed: isCheckedToday 
                          ? null // Disable if already checked
                          : () => _checkIn(ref, habit),
                    ),
                  ],
                ),
                if (habit.streakDates != null && habit.streakDates!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('最近打卡:', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    children: habit.streakDates!.reversed.take(5).map((date) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          DateFormat('MM-dd').format(date),
                          style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  bool _isCheckedToday(PlanEvent habit) {
    if (habit.streakDates == null || habit.streakDates!.isEmpty) return false;
    final lastDate = habit.streakDates!.last;
    final now = DateTime.now();
    return lastDate.year == now.year && 
           lastDate.month == now.month && 
           lastDate.day == now.day;
  }

  void _checkIn(WidgetRef ref, PlanEvent habit) {
    final now = DateTime.now();
    final newDates = List<DateTime>.from(habit.streakDates ?? []);
    newDates.add(now);
    
    // Sort dates just in case
    newDates.sort();

    final updatedHabit = habit.copyWith(
      streakDates: newDates,
      // Also mark as completed for today? No, habits are perpetual.
      // We don't change isCompleted flag for habits usually, or maybe toggle it daily?
      // For simplicity, isCompleted is ignored for habits logic here.
    );
    
    ref.read(planEventsProvider.notifier).updateEvent(updatedHabit);
  }

  void _showEditHabitDialog(BuildContext context, WidgetRef ref, PlanEvent habit) {
    final titleController = TextEditingController(text: habit.title);
    
    // We use the habit's base startTime/endTime as the "default" daily time
    DateTime? defaultStartTime = habit.startTime;
    DateTime? defaultEndTime = habit.endTime;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('编辑长期计划'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: '计划名称'),
                    ),
                    const SizedBox(height: 16),
                    const Text('默认每日时间 (从今日起生效)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ListTile(
                      title: Text(defaultStartTime == null ? '默认开始时间' : '开始: ${DateFormat('HH:mm').format(defaultStartTime!)}'),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: defaultStartTime != null 
                              ? TimeOfDay.fromDateTime(defaultStartTime!) 
                              : TimeOfDay.now(),
                        );
                        if (time != null) {
                          setState(() {
                            final now = DateTime.now();
                            defaultStartTime = DateTime(now.year, now.month, now.day, time.hour, time.minute);
                            if (defaultEndTime == null || defaultEndTime!.isBefore(defaultStartTime!)) {
                              defaultEndTime = defaultStartTime!.add(const Duration(hours: 1));
                            }
                          });
                        }
                      },
                    ),
                    ListTile(
                      title: Text(defaultEndTime == null ? '默认结束时间' : '结束: ${DateFormat('HH:mm').format(defaultEndTime!)}'),
                      trailing: const Icon(Icons.access_time_filled),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: defaultEndTime != null 
                              ? TimeOfDay.fromDateTime(defaultEndTime!) 
                              : TimeOfDay.now(),
                        );
                        if (time != null) {
                          setState(() {
                            final now = DateTime.now();
                            defaultEndTime = DateTime(now.year, now.month, now.day, time.hour, time.minute);
                          });
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
                    if (titleController.text.isNotEmpty) {
                      DateTime? newBaseStart;
                      DateTime? newBaseEnd;
                      
                      if (defaultStartTime != null) {
                        final originalDate = habit.startTime ?? DateTime.now();
                        newBaseStart = DateTime(
                          originalDate.year, 
                          originalDate.month, 
                          originalDate.day, 
                          defaultStartTime!.hour, 
                          defaultStartTime!.minute
                        );
                      }
                      
                      if (defaultEndTime != null) {
                        final originalDate = habit.startTime ?? DateTime.now();
                        newBaseEnd = DateTime(
                          originalDate.year, 
                          originalDate.month, 
                          originalDate.day, 
                          defaultEndTime!.hour, 
                          defaultEndTime!.minute
                        );
                      }

                      final updatedHabit = habit.copyWith(
                        title: titleController.text,
                        startTime: newBaseStart,
                        endTime: newBaseEnd,
                      );
                      
                      ref.read(planEventsProvider.notifier).updateEvent(updatedHabit);
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
}

class _CountdownList extends ConsumerWidget {
  const _CountdownList();

  void _showEditCountdownDialog(BuildContext context, WidgetRef ref, PlanEvent event) {
    final titleController = TextEditingController(text: event.title);
    DateTime? selectedDate = event.deadline;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('编辑倒计时'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: '事件名称',
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: Text(selectedDate == null
                      ? '选择截止时间'
                      : '截止: ${DateFormat('yyyy-MM-dd HH:mm').format(selectedDate!)}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate ?? DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (date != null && context.mounted) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: selectedDate != null
                            ? TimeOfDay.fromDateTime(selectedDate!)
                            : const TimeOfDay(hour: 0, minute: 0),
                      );
                      if (time != null) {
                        setState(() {
                          selectedDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                        });
                      }
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (titleController.text.isNotEmpty && selectedDate != null) {
                    final updatedEvent = event.copyWith(
                      title: titleController.text,
                      deadline: selectedDate,
                    );
                    ref.read(planEventsProvider.notifier).updateEvent(updatedEvent);
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('请输入名称并选择截止时间')),
                    );
                  }
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allEvents = ref.watch(planEventsProvider);
    final countdowns = allEvents.where((e) => e.isCountdown).toList();

    // Sort by nearest deadline first
    countdowns.sort((a, b) => (a.deadline ?? DateTime.now()).compareTo(b.deadline ?? DateTime.now()));

    if (countdowns.isEmpty) {
      return const Center(child: Text('暂无倒计时事件，点击右下角添加'));
    }

    return ListView.builder(
      itemCount: countdowns.length,
      itemBuilder: (context, index) {
        final event = countdowns[index];
        final deadline = event.deadline;
        
        if (deadline == null) return const SizedBox();

        final now = DateTime.now();
        
        // Use full date time for more accurate diff, but keep display simple
        final diffDuration = deadline.difference(now);
        final diffDays = diffDuration.inDays;
        
        // Determine color based on days left
        Color cardColor;
        if (diffDuration.isNegative) {
          // Passed deadline
          cardColor = Colors.grey.shade400;
        } else if (diffDays > 10) {
          cardColor = Colors.grey.shade200;
        } else if (diffDays >= 3) {
          cardColor = Colors.blue.shade100;
        } else if (diffDays >= 1) {
          cardColor = Colors.yellow.shade100;
        } else {
          // <= 1 day
          cardColor = Colors.red.shade100;
        }

        String daysText;
        if (diffDuration.isNegative) {
          // For negative duration, invert it to get positive days/hours passed
          final pastDuration = now.difference(deadline);
          if (pastDuration.inDays > 0) {
            daysText = '已过期 ${pastDuration.inDays} 天';
          } else {
            daysText = '已过期 ${pastDuration.inHours} 小时';
          }
        } else {
          if (diffDays > 0) {
            daysText = '$diffDays 天';
          } else {
            // Less than 24 hours left
            final hours = diffDuration.inHours;
            if (hours > 0) {
              daysText = '$hours 小时';
            } else {
              daysText = '${diffDuration.inMinutes} 分钟';
            }
          }
        }

        return Card(
          color: cardColor,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text(
              event.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            subtitle: Text('截止: ${DateFormat('yyyy-MM-dd HH:mm').format(deadline)}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    daysText,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: diffDuration.isNegative 
                          ? Colors.black54 
                          : (diffDays <= 1 ? Colors.red.shade700 : Colors.black87),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blueGrey),
                  tooltip: '编辑倒计时',
                  onPressed: () => _showEditCountdownDialog(context, ref, event),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.black54),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('删除倒计时'),
                        content: const Text('确定要删除这个倒计时吗？'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                          TextButton(
                            onPressed: () {
                              ref.read(planEventsProvider.notifier).deleteEvent(event);
                              Navigator.pop(ctx);
                            },
                            child: const Text('删除', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
