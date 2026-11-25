import 'dart:math';

class RetryPolicy {
  const RetryPolicy({
    this.initialDelay = const Duration(seconds: 2),
    this.maximumDelay = const Duration(minutes: 5),
    this.maximumAttempts = 12,
    this.jitterFraction = 0.20,
  });

  final Duration initialDelay;
  final Duration maximumDelay;
  final int maximumAttempts;
  final double jitterFraction;

  Duration delayForAttempt(int attempt, Random random) {
    if (attempt <= 0) return Duration.zero;
    final exponentialSeconds =
        initialDelay.inMilliseconds * pow(2, attempt - 1);
    final capped = min(
      exponentialSeconds,
      maximumDelay.inMilliseconds,
    ).toInt();
    final jitterRange = (capped * jitterFraction).floor();
    final jitter = jitterRange == 0
        ? 0
        : random.nextInt(jitterRange * 2 + 1) - jitterRange;
    return Duration(
      milliseconds: max(0, capped + jitter),
    );
  }

  bool mayRetry(int attempt) => attempt >= 0 && attempt < maximumAttempts;
}
