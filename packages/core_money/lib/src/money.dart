import 'currency.dart';
import 'rounding_policy.dart';

class Money {
  const Money._({
    required this.minorUnits,
    required this.currency,
  });

  factory Money({
    required BigInt minorUnits,
    required Currency currency,
  }) {
    return Money._(minorUnits: minorUnits, currency: currency);
  }

  factory Money.fromMajor({
    required BigInt majorUnits,
    required Currency currency,
  }) {
    return Money._(
      minorUnits: majorUnits * currency.minorUnitFactor,
      currency: currency,
    );
  }

  factory Money.zero(Currency currency) =>
      Money(minorUnits: BigInt.zero, currency: currency);

  factory Money.parse(String text, Currency currency) {
    final normalized = text.trim();
    final match = RegExp(r'^([+-]?)(\d+)(?:\.(\d*))?$').firstMatch(normalized);
    if (match == null) {
      throw FormatException('Invalid decimal money value', text);
    }

    final sign = match.group(1) == '-' ? BigInt.from(-1) : BigInt.one;
    final whole = match.group(2)!;
    final fraction = match.group(3) ?? '';
    final digits = currency.minorUnitDigits;

    if (fraction.length > digits) {
      throw FormatException(
        'Value has more than $digits decimal places',
        text,
      );
    }

    final padded = fraction.padRight(digits, '0');
    final minorText = '$whole${padded.isEmpty ? '' : padded}';
    final minor = BigInt.parse(minorText) * sign;
    return Money(minorUnits: minor, currency: currency);
  }

  final BigInt minorUnits;
  final Currency currency;

  bool get isZero => minorUnits == BigInt.zero;
  bool get isNegative => minorUnits.isNegative;

  void requireSameCurrency(Money other) {
    if (currency != other.currency) {
      throw ArgumentError(
        'Currency mismatch: ${currency.code} != ${other.currency.code}',
      );
    }
  }

  Money operator +(Money other) {
    requireSameCurrency(other);
    return Money(
      minorUnits: minorUnits + other.minorUnits,
      currency: currency,
    );
  }

  Money operator -(Money other) {
    requireSameCurrency(other);
    return Money(
      minorUnits: minorUnits - other.minorUnits,
      currency: currency,
    );
  }

  Money operator *(BigInt quantity) => Money(
        minorUnits: minorUnits * quantity,
        currency: currency,
      );

  Money absolute() => Money(
        minorUnits: minorUnits.abs(),
        currency: currency,
      );

  Money negate() => Money(
        minorUnits: -minorUnits,
        currency: currency,
      );

  Money maxZero() => minorUnits.isNegative ? Money.zero(currency) : this;

  Money rounded({
    RoundingPolicy policy = RoundingPolicy.commercial,
  }) =>
      Money(
          minorUnits: policy.roundRatio(minorUnits, BigInt.one),
          currency: currency);

  Money multiplyByRatio({
    required BigInt numerator,
    required BigInt denominator,
    RoundingPolicy policy = RoundingPolicy.commercial,
  }) {
    if (denominator == BigInt.zero) {
      throw ArgumentError.value(denominator, 'denominator');
    }
    return Money(
      minorUnits: policy.roundRatio(minorUnits * numerator, denominator),
      currency: currency,
    );
  }

  String toDecimalString() {
    final sign = minorUnits.isNegative ? '-' : '';
    final absolute = minorUnits.abs();
    final digits = currency.minorUnitDigits;
    if (digits == 0) {
      return '$sign$absolute';
    }

    final factor = currency.minorUnitFactor;
    final whole = absolute ~/ factor;
    final fraction = (absolute % factor).toString().padLeft(digits, '0');
    return '$sign$whole.$fraction';
  }

  String format() => '${currency.code} ${toDecimalString()}';

  @override
  bool operator ==(Object other) =>
      other is Money &&
      minorUnits == other.minorUnits &&
      currency == other.currency;

  @override
  int get hashCode => Object.hash(minorUnits, currency);

  int compareTo(Money other) {
    requireSameCurrency(other);
    return minorUnits.compareTo(other.minorUnits);
  }

  @override
  String toString() => format();
}
