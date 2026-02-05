import 'package:intl/intl.dart';

class RelativeDateFormatter {
  const RelativeDateFormatter._();

  static String format(DateTime dateTime, {DateTime? reference}) {
    final now = reference ?? DateTime.now();
    
    // Normalize to start of day for calendar date comparison
    final recordDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    
    // Check if record is today (00:00 to 23:59 of today's date)
    if (recordDate == today) {
      final difference = now.difference(dateTime);
      if (difference.inSeconds.abs() < 60) {
        return difference.isNegative ? 'In moments' : 'Just now';
      }
      if (difference.isNegative) {
        return 'Later today';
      }
      return 'Today';
    }
    
    // Check if record is yesterday (00:00 to 23:59 of yesterday's date)
    if (recordDate == yesterday) {
      return 'Yesterday';
    }
    
    final difference = now.difference(dateTime);
    
    if (difference.isNegative) {
      return _formatFuture(dateTime, now);
    }

    final days = difference.inDays;
    if (days < 7) {
      return DateFormat('EEEE').format(dateTime);
    }
    if (days < 14) {
      final weekday = DateFormat('EEEE').format(dateTime);
      return '$weekday, last week';
    }
    if (days < 30) {
      final weeks = (days / 7).floor();
      return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
    }

    final months = _monthDifference(now, dateTime);
    if (months < 12) {
      if (months <= 1) {
        return '1 month ago';
      }
      return '$months months ago';
    }

    final years = _yearDifference(now, dateTime);
    return years == 1 ? '1 year ago' : '$years years ago';
  }

  static String _formatFuture(DateTime dateTime, DateTime reference) {
    final difference = dateTime.difference(reference);
    final days = difference.inDays;
    if (days == 0) {
      return 'Later today';
    }
    if (days == 1) {
      return 'Tomorrow';
    }
    if (days < 7) {
      return DateFormat('EEEE').format(dateTime);
    }
    if (days < 14) {
      final weekday = DateFormat('EEEE').format(dateTime);
      return '$weekday, next week';
    }
    if (days < 30) {
      final weeks = (days / 7).ceil();
      return weeks == 1 ? 'In 1 week' : 'In $weeks weeks';
    }

    final months = _monthDifference(dateTime, reference);
    if (months < 12) {
      if (months <= 1) {
        return 'In 1 month';
      }
      return 'In $months months';
    }

    final years = _yearDifference(dateTime, reference);
    return years == 1 ? 'In 1 year' : 'In $years years';
  }

  static int _monthDifference(DateTime later, DateTime earlier) {
    final yearDiff = later.year - earlier.year;
    final monthDiff = later.month - earlier.month;
    var months = yearDiff * 12 + monthDiff;
    if (later.day < earlier.day) {
      months -= 1;
    }
    return months;
  }

  static int _yearDifference(DateTime later, DateTime earlier) {
    var years = later.year - earlier.year;
    if (later.month < earlier.month ||
        (later.month == earlier.month && later.day < earlier.day)) {
      years -= 1;
    }
    return years;
  }
}

