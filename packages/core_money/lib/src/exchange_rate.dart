import 'currency.dart';
import 'rounding_policy.dart';

class ExchangeRate {
  ExchangeRate({
    required this.base,
    required this.quote,
    required this.numerator,
    required this.denominator,
    required this.effectiveFrom,
    this.effectiveTo,
    required this.source,
  }) {
    if (numerator <= BigInt.zero) {
      throw ArgumentError.value(numerator, 'numerator', 'Must be positive');
    }
    if (denominator <= BigInt.zero) {
      throw ArgumentError.value(denominator, 'denominator', 'Must be positive');
    }
  }

  factory ExchangeRate.parseDecimal({
    required Currency base,
    required Currency quote,
    required String quoteUnitsPerBase,
    required DateTime effectiveFrom,
    DateTime? effectiveTo,
    required String source,
  }) {
    final normalized = quoteUnitsPerBase.trim();
    final match = RegExp(r'^([+]?\d+)(?:\.(\d*))?$').firstMatch(normalized);
    if (match == null) {
      throw FormatException(
        'Invalid exchange rate decimal',
        quoteUnitsPerBase,
      );
    }

    final whole = match.group(1)!;
    final fraction = match.group(2) ?? '';
    final scale = quote.minorUnitDigits;
    if (fraction.length > scale) {
      throw FormatException(
        'Exchange rate has more than $scale decimal places',
        quoteUnitsPerBase,
      );
    }
    final numerator = BigInt.parse('$whole${fraction.padRight(scale, '0')}');
    final denominator = quote.minorUnitFactor;

    if (numerator <= BigInt.zero) {
      throw ArgumentError.value(
        quoteUnitsPerBase,
        'quoteUnitsPerBase',
        'Must be positive',
      );
    }

    return ExchangeRate(
      base: base,
      quote: quote,
      numerator: numerator,
      denominator: denominator,
      effectiveFrom: effectiveFrom,
      effectiveTo: effectiveTo,
      source: source,
    );
  }

  final Currency base;
  final Currency quote;
  final BigInt numerator;
  final BigInt denominator;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
  final String source;

  bool isEffectiveAt(DateTime at) {
    final instant = at.toUtc();
    final from = effectiveFrom.toUtc();
    final to = effectiveTo?.toUtc();
    return !instant.isBefore(from) && (to == null || !instant.isAfter(to));
  }

  ExchangeRate requireEffectiveAt(DateTime at) {
    if (!isEffectiveAt(at)) {
      throw StateError('Exchange rate is not effective at $at');
    }
    return this;
  }

  BigInt convertMinorUnits(
    BigInt baseMinorUnits,
    RoundingPolicy policy,
  ) {
    final numerator = baseMinorUnits * numeratorValue * quote.minorUnitFactor;
    final denominator = base.minorUnitFactor * denominatorValue;
    return policy.roundRatio(numerator, denominator);
  }

  BigInt get numeratorValue => numerator;
  BigInt get denominatorValue => denominator;
}
