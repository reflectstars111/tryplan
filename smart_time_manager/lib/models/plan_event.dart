import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'plan_event.g.dart';

@HiveType(typeId: 0)
class PlanEvent extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  DateTime? startTime;

  @HiveField(3)
  DateTime? endTime;

  @HiveField(4)
  String? location;

  @HiveField(5)
  bool isImportant;

  @HiveField(6)
  bool isUrgent;

  @HiveField(7)
  bool isCompleted;

  @HiveField(8)
  int sortOrder;

  @HiveField(9)
  bool isHabit; // Is this a long-term habit?

  @HiveField(10)
  List<DateTime>? streakDates; // Dates when habit was completed

  @HiveField(11)
  Map<String, Map<String, DateTime?>>? habitExceptions; // Store custom start/end times per date string (yyyy-MM-dd)

  @HiveField(12)
  bool isCountdown; // Is this a countdown event?

  @HiveField(13)
  DateTime? deadline; // The target date for the countdown

  PlanEvent({
    String? id,
    required this.title,
    this.startTime,
    this.endTime,
    this.location,
    required this.isImportant,
    required this.isUrgent,
    this.isCompleted = false,
    this.sortOrder = 0,
    this.isHabit = false,
    this.streakDates,
    this.habitExceptions,
    this.isCountdown = false,
    this.deadline,
  }) : id = id ?? const Uuid().v4();

  PlanEvent copyWith({
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
    bool? isImportant,
    bool? isUrgent,
    bool? isCompleted,
    int? sortOrder,
    bool? isHabit,
    List<DateTime>? streakDates,
    Map<String, Map<String, DateTime?>>? habitExceptions,
    bool? isCountdown,
    DateTime? deadline,
  }) {
    return PlanEvent(
      id: id,
      title: title ?? this.title,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      isImportant: isImportant ?? this.isImportant,
      isUrgent: isUrgent ?? this.isUrgent,
      isCompleted: isCompleted ?? this.isCompleted,
      sortOrder: sortOrder ?? this.sortOrder,
      isHabit: isHabit ?? this.isHabit,
      streakDates: streakDates ?? this.streakDates,
      habitExceptions: habitExceptions ?? this.habitExceptions,
      isCountdown: isCountdown ?? this.isCountdown,
      deadline: deadline ?? this.deadline,
    );
  }
}
