import 'package:flutter_riverpod/flutter_riverpod.dart';

final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  // Default to today, normalized to 00:00:00
  return DateTime(now.year, now.month, now.day);
});
