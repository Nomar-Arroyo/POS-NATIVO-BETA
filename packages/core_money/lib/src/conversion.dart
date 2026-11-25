import 'currency.dart';
import 'exchange_rate.dart';
import 'money.dart';
import 'rounding_policy.dart';

class Conversion {
  const Conversion({
    this.policy = RoundingPolicy.commercial,
  });

  final RoundingPolicy policy;

  Money convert(
    Money amount,
    ExchangeRate rate,
  ) {
    if (amount.currency != rate.base) {
      throw ArgumentError(
        'Amount currency ${amount.currency.code} does not match '
        'rate base ${rate.base.code}',
      );
    }

    final converted = rate.convertMinorUnits(
      amount.minorUnits,
      policy,
    );
    return Money(minorUnits: converted, currency: rate.quote);
  }

  Money convertAt(
    Money amount,
    ExchangeRate rate,
    DateTime operationTime,
  ) =>
      convert(amount, rate.requireEffectiveAt(operationTime));

  MixedPaymentResult settleMixedPayment({
    required Money total,
    required List<Money> payments,
    required ExchangeRate paymentRate,
    DateTime? operationTime,
  }) {
    if (payments.isEmpty) {
      throw ArgumentError.value(payments, 'payments', 'Cannot be empty');
    }
    if (operationTime != null) {
      paymentRate.requireEffectiveAt(operationTime);
    }

    final paid = <Currency, BigInt>{};
    for (final payment in payments) {
      if (payment.minorUnits < BigInt.zero) {
        throw ArgumentError.value(payment, 'payment', 'Must not be negative');
      }
      paid.update(
        payment.currency,
        (value) => value + payment.minorUnits,
        ifAbsent: () => payment.minorUnits,
      );
    }

    var totalPaidInTotalCurrency = Money.zero(total.currency);
    for (final entry in paid.entries) {
      final currencyPaid = Money(
        minorUnits: entry.value,
        currency: entry.key,
      );
      if (entry.key == total.currency) {
        totalPaidInTotalCurrency = totalPaidInTotalCurrency + currencyPaid;
        continue;
      }

      final directRate = entry.key == paymentRate.base &&
              total.currency == paymentRate.quote
          ? paymentRate
          : entry.key == paymentRate.quote && total.currency == paymentRate.base
              ? _inverseRate(paymentRate)
              : null;
      if (directRate == null) {
        throw ArgumentError(
          'No conversion is configured for ${entry.key.code} '
          'to ${total.currency.code}',
        );
      }
      totalPaidInTotalCurrency =
          totalPaidInTotalCurrency + convert(currencyPaid, directRate);
    }

    final remaining = (total - totalPaidInTotalCurrency).maxZero();
    final change = totalPaidInTotalCurrency - total;
    final changeMoney =
        (change.isNegative ? Money.zero(total.currency) : change);

    return MixedPaymentResult(
      totalPaid: totalPaidInTotalCurrency,
      remaining: remaining,
      change: changeMoney,
      paidByCurrency: paid,
    );
  }

  ExchangeRate _inverseRate(ExchangeRate rate) {
    return ExchangeRate(
      base: rate.quote,
      quote: rate.base,
      numerator: rate.denominator,
      denominator: rate.numerator,
      effectiveFrom: rate.effectiveFrom,
      effectiveTo: rate.effectiveTo,
      source: '${rate.source}:inverse',
    );
  }
}

class MixedPaymentResult {
  const MixedPaymentResult({
    required this.totalPaid,
    required this.remaining,
    required this.change,
    required this.paidByCurrency,
  });

  final Money totalPaid;
  final Money remaining;
  final Money change;
  final Map<Currency, BigInt> paidByCurrency;

  bool get isPaid => remaining.isZero;
}

class Payment {
  const Payment({
    required this.originalAmount,
    required this.exchangeRateSnapshot,
    required this.method,
  });

  final Money originalAmount;
  final ExchangeRate exchangeRateSnapshot;
  final String method;
}
