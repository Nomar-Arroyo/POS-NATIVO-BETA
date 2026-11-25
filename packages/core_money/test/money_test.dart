import 'package:core_money/core_money.dart';
import 'package:test/test.dart';

void main() {
  group('Money', () {
    test('parses and formats exact minor units', () {
      expect(
          Money.parse('1234.56', Currency.usd).minorUnits, BigInt.from(123456));
      expect(Money.parse('-0.01', Currency.usd).minorUnits, BigInt.from(-1));
      expect(Money.parse('1234.56', Currency.usd).toDecimalString(), '1234.56');
    });

    test('rejects excess decimal scale and malformed values', () {
      expect(
        () => Money.parse('1.001', Currency.usd),
        throwsFormatException,
      );
      expect(
        () => Money.parse('not-money', Currency.usd),
        throwsFormatException,
      );
    });

    test('adds and subtracts only matching currencies', () {
      final ten = Money.parse('10.00', Currency.usd);
      final one = Money.parse('1.25', Currency.usd);
      expect((ten - one).toDecimalString(), '8.75');
      expect(
        () => ten + Money.parse('1.00', Currency.ves),
        throwsArgumentError,
      );
    });

    test('handles arbitrarily large integer minor units', () {
      final huge = BigInt.parse('999999999999999999999999999999999999');
      final money = Money(minorUnits: huge, currency: Currency.usd);
      expect((money + money).minorUnits, huge + huge);
    });
  });

  group('RoundingPolicy', () {
    test('rounds half up for positive and negative ratios', () {
      const policy = RoundingPolicy(mode: RoundingMode.halfUp);
      expect(policy.roundRatio(BigInt.from(5), BigInt.from(2)), BigInt.from(3));
      expect(
          policy.roundRatio(BigInt.from(-5), BigInt.from(2)), BigInt.from(-3));
    });

    test('supports half even', () {
      const policy = RoundingPolicy(mode: RoundingMode.halfEven);
      expect(
          policy.roundRatio(BigInt.from(25), BigInt.from(10)), BigInt.from(2));
      expect(
          policy.roundRatio(BigInt.from(35), BigInt.from(10)), BigInt.from(4));
    });
  });

  group('ExchangeRate and Conversion', () {
    final effectiveFrom = DateTime.utc(2026, 1, 1);

    test('converts USD to VES exactly and preserves historical rate', () {
      final rate = ExchangeRate.parseDecimal(
        base: Currency.usd,
        quote: Currency.ves,
        quoteUnitsPerBase: '36.50',
        effectiveFrom: effectiveFrom,
        source: 'test-bcv',
      );
      final result = const Conversion().convert(
        Money.parse('10.01', Currency.usd),
        rate,
      );

      expect(result.currency, Currency.ves);
      expect(result.toDecimalString(), '365.37');
      expect(rate.numerator, BigInt.from(3650));
      expect(rate.denominator, BigInt.from(100));
    });

    test('rejects a rate outside its effective interval', () {
      final rate = ExchangeRate.parseDecimal(
        base: Currency.usd,
        quote: Currency.ves,
        quoteUnitsPerBase: '36.50',
        effectiveFrom: effectiveFrom,
        effectiveTo: DateTime.utc(2026, 1, 31),
        source: 'test',
      );

      expect(
        () => const Conversion().convertAt(
          Money.parse('1.00', Currency.usd),
          rate,
          DateTime.utc(2026, 2, 1),
        ),
        throwsStateError,
      );
    });

    test('settles mixed USD and VES payments', () {
      final rate = ExchangeRate.parseDecimal(
        base: Currency.usd,
        quote: Currency.ves,
        quoteUnitsPerBase: '36.50',
        effectiveFrom: effectiveFrom,
        source: 'test',
      );
      final result = const Conversion().settleMixedPayment(
        total: Money.parse('20.00', Currency.usd),
        payments: [
          Money.parse('10.00', Currency.usd),
          Money.parse('365.00', Currency.ves),
        ],
        paymentRate: rate,
      );

      expect(result.isPaid, isTrue);
      expect(result.remaining.isZero, isTrue);
      expect(result.change.isZero, isTrue);
    });

    test('calculates remaining balance and change', () {
      final rate = ExchangeRate.parseDecimal(
        base: Currency.usd,
        quote: Currency.ves,
        quoteUnitsPerBase: '40.00',
        effectiveFrom: effectiveFrom,
        source: 'test',
      );
      final partial = const Conversion().settleMixedPayment(
        total: Money.parse('20.00', Currency.usd),
        payments: [
          Money.parse('5.00', Currency.usd),
          Money.parse('400.00', Currency.ves),
        ],
        paymentRate: rate,
      );
      expect(partial.remaining.toDecimalString(), '5.00');

      final overpaid = const Conversion().settleMixedPayment(
        total: Money.parse('20.00', Currency.usd),
        payments: [
          Money.parse('20.00', Currency.usd),
          Money.parse('100.00', Currency.ves),
        ],
        paymentRate: rate,
      );
      expect(overpaid.change.toDecimalString(), '2.50');
    });
  });

  group('TaxCalculation', () {
    test('does not enable taxes without an explicit rule', () {
      final result = const TaxCalculation().calculate(
        subtotal: Money.parse('100.00', Currency.usd),
        rules: const [],
      );
      expect(result.taxTotal.isZero, isTrue);
      expect(result.total.toDecimalString(), '100.00');
    });

    test('calculates an explicitly supplied tax rule', () {
      final result = const TaxCalculation().calculate(
        subtotal: Money.parse('100.00', Currency.usd),
        rules: const [
          TaxRule(
            code: 'TEST_TAX',
            numerator: 16,
            denominator: 100,
          ),
        ],
      );
      expect(result.taxes['TEST_TAX']!.toDecimalString(), '16.00');
      expect(result.total.toDecimalString(), '116.00');
    });
  });
}
