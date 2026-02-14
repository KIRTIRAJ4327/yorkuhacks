/// Formatting utilities for display
class FormatUtils {
  FormatUtils._();

  /// Format distance in meters to human-readable string
  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  /// Format duration in seconds to human-readable string
  static String formatDuration(int seconds) {
    if (seconds < 60) {
      return '< 1 min';
    }
    final minutes = (seconds / 60).round();
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) {
      return '$hours hr';
    }
    return '$hours hr $remainingMinutes min';
  }

  /// Format safety score to display string
  static String formatScore(double score) {
    return score.round().toString();
  }

  /// Format percentage
  static String formatPercent(double value) {
    return '${value.round()}%';
  }
}
