import '../../core/widgets/dp_ui.dart';

/// Numbers for the vet dashboard and analytics, worked out from the
/// vet's case history (GET /vet/history -> [{review, result}, ...]).
class VetStats {
  final int total;
  final int confirmed; // vet agreed with the AI
  final int corrected; // vet changed the AI's diagnosis
  final int confirmedThisWeek;
  final int correctedThisWeek;
  final List<double> last7Days; // reviews per day, oldest first
  final List<String> last7Labels; // "Mon", "Tue", ...
  final List<double> last8Weeks; // reviews per week, oldest first
  final Map<String, int> byDecision; // final diagnosis -> count

  VetStats._({
    required this.total,
    required this.confirmed,
    required this.corrected,
    required this.confirmedThisWeek,
    required this.correctedThisWeek,
    required this.last7Days,
    required this.last7Labels,
    required this.last8Weeks,
    required this.byDecision,
  });

  static const _dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

  factory VetStats.fromHistory(List<dynamic> history) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(const Duration(days: 6));

    int confirmed = 0, corrected = 0, confirmedWeek = 0, correctedWeek = 0;
    final days = List<double>.filled(7, 0);
    final weeks = List<double>.filled(8, 0);
    final byDecision = <String, int>{};

    for (final entry in history) {
      final review = (entry is Map ? entry["review"] : null) ?? {};
      final result = (entry is Map ? entry["result"] : null) ?? {};
      final decision = (review["decision"] ?? "Unknown").toString();
      final ai = (result["predicted_disease"] ?? "").toString();
      final isConfirmed = decision == ai;

      // review_date is new; older servers only send the scan date
      final d = dpParseDate(review["review_date"]) ?? dpParseDate(result["result_date"]);
      final day = d == null ? null : DateTime(d.year, d.month, d.day);
      final inLastWeek = day != null && !day.isBefore(weekStart);

      if (isConfirmed) {
        confirmed++;
        if (inLastWeek) confirmedWeek++;
      } else {
        corrected++;
        if (inLastWeek) correctedWeek++;
      }
      byDecision[decision] = (byDecision[decision] ?? 0) + 1;

      if (day != null) {
        final daysAgo = today.difference(day).inDays;
        if (daysAgo >= 0 && daysAgo < 7) days[6 - daysAgo] += 1;
        final weeksAgo = daysAgo ~/ 7;
        if (daysAgo >= 0 && weeksAgo < 8) weeks[7 - weeksAgo] += 1;
      }
    }

    final labels = List<String>.generate(7, (i) {
      final d = today.subtract(Duration(days: 6 - i));
      return _dayNames[d.weekday - 1];
    });

    return VetStats._(
      total: history.length,
      confirmed: confirmed,
      corrected: corrected,
      confirmedThisWeek: confirmedWeek,
      correctedThisWeek: correctedWeek,
      last7Days: days,
      last7Labels: labels,
      last8Weeks: weeks,
      byDecision: byDecision,
    );
  }

  factory VetStats.empty() => VetStats.fromHistory(const []);
}
