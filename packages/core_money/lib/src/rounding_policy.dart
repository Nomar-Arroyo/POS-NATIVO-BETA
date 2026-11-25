enum RoundingMode {
  down,
  halfUp,
  halfEven,
  ceiling,
  floor,
}

class RoundingPolicy {
  const RoundingPolicy({
    this.mode = RoundingMode.halfUp,
  });

  final RoundingMode mode;

  static const RoundingPolicy commercial =
      RoundingPolicy(mode: RoundingMode.halfUp);

  BigInt roundRatio(BigInt numerator, BigInt denominator) {
    if (denominator == BigInt.zero) {
      throw ArgumentError.value(denominator, 'denominator', 'Cannot be zero');
    }

    final negative = (numerator.isNegative) != (denominator.isNegative);
    final n = numerator.abs();
    final d = denominator.abs();
    final quotient = n ~/ d;
    final remainder = n - (quotient * d);

    BigInt sign(BigInt value) => negative ? -value : value;

    if (remainder == BigInt.zero) {
      return sign(quotient);
    }

    switch (mode) {
      case RoundingMode.down:
        return sign(quotient);
      case RoundingMode.ceiling:
        return negative ? sign(quotient) : sign(quotient + BigInt.one);
      case RoundingMode.floor:
        return negative ? sign(quotient + BigInt.one) : sign(quotient);
      case RoundingMode.halfEven:
        return _roundHalf(quotient, remainder, d, negative, tieToEven: true);
      case RoundingMode.halfUp:
        return _roundHalf(quotient, remainder, d, negative, tieToEven: false);
    }
  }

  BigInt _roundHalf(
    BigInt quotient,
    BigInt remainder,
    BigInt denominator,
    bool negative, {
    required bool tieToEven,
  }) {
    final twiceRemainder = remainder * BigInt.from(2);
    if (twiceRemainder < denominator) {
      return negative ? -quotient : quotient;
    }
    if (twiceRemainder > denominator) {
      final result = quotient + BigInt.one;
      return negative ? -result : result;
    }

    if (tieToEven) {
      final result = quotient.isEven ? quotient : quotient + BigInt.one;
      return negative ? -result : result;
    }

    final result = quotient + BigInt.one;
    return negative ? -result : result;
  }
}
