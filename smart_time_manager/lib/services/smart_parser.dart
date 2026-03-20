import 'package:smart_time_manager/models/plan_event.dart';

class SmartParserService {
  /// Local Heuristic Engine
  /// Parses input string to extract:
  /// - Title (remaining text)
  /// - Time (e.g., "14点", "明天下午3点")
  /// - Quadrant info (e.g., "紧急", "重要")
  static PlanEvent parse(String input) {
    // Work on a copy of input string to remove extracted parts
    String remainingText = input;
    DateTime? startTime;
    String? location;
    bool isImportant = false;
    bool isUrgent = false;

    // 1. Parse Quadrant Keywords
    if (remainingText.contains('紧急')) {
      isUrgent = true;
      remainingText = remainingText.replaceAll('紧急', '');
    }
    if (remainingText.contains('重要')) {
      isImportant = true;
      remainingText = remainingText.replaceAll('重要', '');
    }
    
    // 2. Parse Date Keywords (Simple)
    final now = DateTime.now();
    DateTime targetDate = now;

    // Handle "明天", "后天"
    // Note: The order matters. "后天" contains "天", but not "明天".
    // "明天下午" -> "明天" + "下午"
    if (input.contains('明天')) {
      targetDate = now.add(const Duration(days: 1));
      remainingText = remainingText.replaceAll('明天', '');
    } else if (input.contains('后天')) {
      targetDate = now.add(const Duration(days: 2));
      remainingText = remainingText.replaceAll('后天', '');
    }

    // 3. Parse Time (Regex)
    // Matches: "下午3点", "14点", "14:30", "3点半", "晚上8点"
    // Regex breakdown:
    // (上午|下午|晚上)? : Optional period prefix
    // \s* : Optional whitespace
    // (\d{1,2}) : Hour (1-2 digits)
    // [:点] : Separator
    // (\d{2}|半)? : Minute (2 digits OR "半")
    final timeRegex = RegExp(r'(上午|下午|晚上)?\s*(\d{1,2})[:点](\d{2}|半)?');
    final match = timeRegex.firstMatch(remainingText);
    
    if (match != null) {
      final period = match.group(1); // 上午/下午/晚上
      final hourStr = match.group(2);
      final minuteStr = match.group(3); // "30" or "半"
      
      if (hourStr != null) {
        int hour = int.parse(hourStr);
        int minute = 0;
        
        if (minuteStr == '半') {
          minute = 30;
        } else if (minuteStr != null) {
          minute = int.parse(minuteStr);
        }
        
        // Handle PM logic
        bool isPM = false;
        if (period == '下午' || period == '晚上') {
          isPM = true;
        } else {
           // Fallback check in text if regex didn't capture period
           // (e.g. "明天下午3点" -> "明天" removed, "下午" remains but regex might miss it if separated)
           if (remainingText.contains('下午')) isPM = true;
           if (remainingText.contains('晚上')) isPM = true;
        }

        // Adjust hour for PM
        if (isPM && hour < 12) {
          hour += 12;
        }
        // Adjust hour for 12 AM (midnight) ? 
        // Usually "晚上12点" means next day 0:00 or current day 24:00.
        // Let's assume 0-23 format.

        // Construct DateTime with targetDate
        startTime = DateTime(targetDate.year, targetDate.month, targetDate.day, hour, minute);
        
        // Remove extracted time parts from title
        // Remove the match
        remainingText = remainingText.replaceFirst(match.group(0)!, '');
        // Cleanup keywords that might be outside the regex match group 1 but used for logic
        // Only remove if they were used for logic and likely part of time expression
        if (isPM && period == null) {
           remainingText = remainingText.replaceFirst('下午', '');
           remainingText = remainingText.replaceFirst('晚上', '');
        }
        if (remainingText.contains('上午')) {
           remainingText = remainingText.replaceFirst('上午', '');
        }
        
        // Remove "点" if it was left over (e.g. "3点")
        remainingText = remainingText.replaceAll('点', '');
        remainingText = remainingText.replaceAll(':', '');
      }
    }

    // 4. Parse Location (Simple heuristic: "在xxx", "去xxx")
    // e.g. "在会议室开会", "去健身房"
    final locationRegex = RegExp(r'[在去]([^ ]+)');
    final locMatch = locationRegex.firstMatch(remainingText);
    if (locMatch != null) {
      // Extract location but maybe keep it in title? 
      // PRD says location is extracted.
      // Let's extract simple locations (2-6 chars) to avoid extracting verbs.
      String potentialLoc = locMatch.group(1)!;
      // Heuristic: if it looks like a place
      location = potentialLoc;
      
      // Optional: remove location from title or keep it?
      // Usually "在会议室" -> Location: 会议室. Title: 开会.
      // Let's remove the whole match "在会议室"
      remainingText = remainingText.replaceFirst(locMatch.group(0)!, '');
    }

    // Clean up title
    String title = remainingText.trim();
    // Remove extra spaces
    title = title.replaceAll(RegExp(r'\s+'), ' ');
    if (title.isEmpty) title = "新任务";

    return PlanEvent(
      title: title,
      isImportant: isImportant,
      isUrgent: isUrgent,
      startTime: startTime,
      endTime: startTime?.add(const Duration(hours: 1)),
      location: location,
    );
  }
}
