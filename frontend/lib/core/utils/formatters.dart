import 'package:intl/intl.dart';

final _indianGrouping = NumberFormat.decimalPattern('en_IN')..maximumFractionDigits = 0;

/// `₹80,634`, `−₹4,500` (true minus, not a hyphen), or `+₹42,000` when
/// [forceSign] is set - matching the design's currency formatting.
String formatCurrency(num value, {bool forceSign = false}) {
  final rounded = value.round();
  final magnitude = _indianGrouping.format(rounded.abs());
  if (rounded < 0) return '−₹$magnitude';
  if (forceSign && rounded > 0) return '+₹$magnitude';
  return '₹$magnitude';
}

String formatCompactCurrency(num value) {
  if (value.abs() >= 1000) {
    return '₹${(value / 1000).toStringAsFixed(1)}k';
  }
  return '₹${value.round()}';
}

const _months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
const _weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

/// 1-indexed month abbreviation, e.g. `monthAbbr(6) == 'JUN'`.
String monthAbbr(int month) => _months[month - 1];

/// `Jan – Jun 2026`
String formatPeriodRange(DateTime start, DateTime end) {
  if (start.year == end.year) {
    return '${_titleCase(_months[start.month - 1])} – ${_titleCase(_months[end.month - 1])} ${end.year}';
  }
  return '${_titleCase(_months[start.month - 1])} ${start.year} – ${_titleCase(_months[end.month - 1])} ${end.year}';
}

/// `28 JUN · SUN`
String formatDayHeader(DateTime date) => '${date.day} ${_months[date.month - 1]} · ${_weekdays[date.weekday - 1]}';

/// `28 JUN 2026`
String formatDate(DateTime date) => '${date.day} ${_months[date.month - 1]} ${date.year}';

/// `04:47 PM`
String formatTime12h(DateTime dt) {
  final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  return '${hour12.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $period';
}

/// `28 JUN 2026 · 04:47 PM`
String formatFullTimestamp(DateTime dt) => '${dt.day} ${_months[dt.month - 1]} ${dt.year} · ${formatTime12h(dt)}';

String _titleCase(String s) => s.isEmpty ? s : '${s[0]}${s.substring(1).toLowerCase()}';
