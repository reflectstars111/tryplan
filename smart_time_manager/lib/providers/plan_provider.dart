import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_time_manager/models/plan_event.dart';

final planEventsProvider = StateNotifierProvider<PlanEventsNotifier, List<PlanEvent>>((ref) {
  final box = Hive.box<PlanEvent>('plan_events');
  return PlanEventsNotifier(box);
});

class PlanEventsNotifier extends StateNotifier<List<PlanEvent>> {
  final Box<PlanEvent> _box;

  PlanEventsNotifier(this._box) : super(_box.values.toList());

  Future<void> addEvent(PlanEvent event) async {
    await _box.put(event.id, event);
    state = _box.values.toList();
  }

  Future<void> updateEvent(PlanEvent event) async {
    // Use put with ID instead of save(), because event might be a copy (unmanaged)
    await _box.put(event.id, event);
    state = _box.values.toList();
  }

  Future<void> deleteEvent(PlanEvent event) async {
    // Since we use copyWith often, the event instance might not be attached to Hive.
    // So we should delete by key rather than calling event.delete().
    await _box.delete(event.id);
    state = _box.values.toList();
  }

  Future<void> toggleComplete(PlanEvent event, {DateTime? date}) async {
    if (event.isHabit && date != null) {
      // Create a normalized date for the key
      final normalizedDate = DateTime(date.year, date.month, date.day);
      
      // Initialize streakDates if null
      List<DateTime> updatedStreakDates = event.streakDates != null 
          ? List<DateTime>.from(event.streakDates!) 
          : [];
          
      // Check if the date is already in the streak
      bool isCompletedOnDate = updatedStreakDates.any((d) => 
          d.year == normalizedDate.year && 
          d.month == normalizedDate.month && 
          d.day == normalizedDate.day);
          
      if (isCompletedOnDate) {
        // Remove from streak
        updatedStreakDates.removeWhere((d) => 
            d.year == normalizedDate.year && 
            d.month == normalizedDate.month && 
            d.day == normalizedDate.day);
      } else {
        // Add to streak
        updatedStreakDates.add(normalizedDate);
      }
      
      final updatedEvent = event.copyWith(streakDates: updatedStreakDates);
      await _box.put(updatedEvent.id, updatedEvent);
      state = _box.values.toList();
    } else {
      // Normal event logic
      final updatedEvent = event.copyWith(isCompleted: !event.isCompleted);
      await _box.put(updatedEvent.id, updatedEvent);
      state = _box.values.toList();
    }
  }
}
