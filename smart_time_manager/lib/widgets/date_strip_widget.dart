import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:smart_time_manager/providers/selected_date_provider.dart';

class DateStripWidget extends ConsumerStatefulWidget {
  const DateStripWidget({super.key});

  @override
  ConsumerState<DateStripWidget> createState() => _DateStripWidgetState();
}

class _DateStripWidgetState extends ConsumerState<DateStripWidget> {
  final ScrollController _scrollController = ScrollController();
  final double _itemWidth = 68.0; // 60 width + 8 margin
  double _sliderValue = 0.0;
  
  // Dynamic window around selected date or today
  late DateTime _startDate;
  late int _totalDays;
  final int _rangeDays = 90; // +/- 90 days (approx 3 months)

  @override
  void initState() {
    super.initState();
    // Initialize window centered around Today
    _resetWindow(DateTime.now());
    
    // Scroll to initial selected date after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedDate(ref.read(selectedDateProvider));
    });

    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        setState(() {
          _sliderValue = _scrollController.offset / _itemWidth;
          // Clamp value
          if (_sliderValue < 0) _sliderValue = 0;
          if (_sliderValue > _totalDays.toDouble()) _sliderValue = _totalDays.toDouble();
        });
      }
    });
  }

  void _resetWindow(DateTime center) {
    // Normalize center to midnight
    final normalizedCenter = DateTime(center.year, center.month, center.day);
    _startDate = normalizedCenter.subtract(Duration(days: _rangeDays));
    _totalDays = _rangeDays * 2 + 1;
    // Reset slider value to center
    _sliderValue = _rangeDays.toDouble();
  }

  void _scrollToSelectedDate(DateTime date) {
    // Check if date is out of current window range
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final diff = normalizedDate.difference(_startDate).inDays;
    
    if (diff < 0 || diff >= _totalDays) {
      // Re-center window if out of bounds
      setState(() {
        _resetWindow(normalizedDate);
      });
      // After rebuild, scroll to center
      WidgetsBinding.instance.addPostFrameCallback((_) {
         _jumpToCenter();
      });
    } else {
      // Scroll to index
      final daysDiff = diff;
      if (daysDiff >= 0) {
        // Center the item: offset = index * width - screenWidth/2 + itemWidth/2
        final screenWidth = MediaQuery.of(context).size.width;
        final offset = (daysDiff * _itemWidth) - (screenWidth / 2) + (_itemWidth / 2);
        
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(offset.clamp(0.0, _scrollController.position.maxScrollExtent));
        }
      }
    }
  }

  void _jumpToCenter() {
     final screenWidth = MediaQuery.of(context).size.width;
     final centerIndex = _rangeDays;
     final offset = (centerIndex * _itemWidth) - (screenWidth / 2) + (_itemWidth / 2);
     if (_scrollController.hasClients) {
        _scrollController.jumpTo(offset.clamp(0.0, _scrollController.position.maxScrollExtent));
     }
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Listen to provider changes to scroll
    ref.listen(selectedDateProvider, (previous, next) {
      _scrollToSelectedDate(next);
    });

    return Container(
      height: 120, // Increased height for Slider + List
      color: isDark ? scheme.surface : Colors.white,
      child: Column(
        children: [
          // Slider for coarse scrolling
          Slider(
            value: _sliderValue.clamp(0.0, _totalDays.toDouble()),
            min: 0.0,
            max: _totalDays.toDouble(),
            onChanged: (value) {
              setState(() {
                _sliderValue = value;
              });
              if (_scrollController.hasClients) {
                _scrollController.jumpTo(value * _itemWidth);
              }
            },
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              itemExtent: _itemWidth, // Fixed extent for performance and logic
              itemCount: _totalDays, 
              itemBuilder: (context, index) {
                final date = _startDate.add(Duration(days: index));
                final isSelected = date.year == selectedDate.year &&
                    date.month == selectedDate.month &&
                    date.day == selectedDate.day;

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final showMonthLabel = date.day == 1 &&
                        constraints.maxHeight >= 60 &&
                        MediaQuery.textScalerOf(context).scale(1) <= 1.2;
                    return GestureDetector(
                      onTap: () {
                        ref.read(selectedDateProvider.notifier).state = DateTime(
                          date.year,
                          date.month,
                          date.day,
                        );
                      },
                      child: Container(
                        width: 60,
                        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark ? scheme.primaryContainer : scheme.primary)
                              : (isDark ? scheme.surfaceContainerHigh : scheme.surface),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: isSelected ? [
                            BoxShadow(
                              color: (isDark ? scheme.primaryContainer : scheme.primary).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          ] : [
                            BoxShadow(
                              color: scheme.shadow.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            )
                          ],
                          border: isSelected
                              ? null
                              : Border.all(
                                  color: isDark ? scheme.outline.withValues(alpha: 0.15) : scheme.outline.withValues(alpha: 0.1),
                                ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DateFormat('E').format(date),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                color: isSelected
                                    ? (isDark ? scheme.onPrimaryContainer : scheme.onPrimary)
                                    : (isDark ? scheme.onSurfaceVariant : scheme.onSurfaceVariant),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              date.day.toString(),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? (isDark ? scheme.onPrimaryContainer : scheme.onPrimary)
                                    : (isDark ? scheme.onSurface : scheme.onSurface),
                              ),
                            ),
                              if (showMonthLabel)
                                Flexible(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      DateFormat('MMM').format(date),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isSelected
                                            ? (isDark ? scheme.onPrimaryContainer.withValues(alpha: 0.8) : scheme.onPrimary.withValues(alpha: 0.8))
                                            : scheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
