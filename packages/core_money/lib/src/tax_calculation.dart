import 'money.dart';
import 'rounding_policy.dart';

class TaxRule {
  const TaxRule({
    required this.code,
    required this.numerator,
    required this.denominator,
    this.inclusive = false,
  })  : assert(numerator >= 0),
        assert(denominator > 0);

  final String code;
  final int numerator;
  final int denominator;
  final bool inclusive;
}

class TaxCalculation {
  const TaxCalculation({
    this.policy = RoundingPolicy.commercial,
  });

  final RoundingPolicy policy;

  TaxResult calculate({
    required Money subtotal,
    required List<TaxRule> rules,
  }) {
    var taxTotal = Money.zero(subtotal.currency);
    var exclusiveTaxTotal = Money.zero(subtotal.currency);
    final taxes = <String, Money>{};

    for (final rule in rules) {
      if (rule.denominator == 0) {
        throw ArgumentError.value(rule.denominator, 'denominator');
      }
      final taxableBase = rule.inclusive
          ? subtotal.multiplyByRatio(
              numerator: BigInt.from(rule.denominator),
              denominator: BigInt.from(rule.denominator + rule.numerator),
              policy: policy,
            )
          : subtotal;
      final tax = taxableBase.multiplyByRatio(
        numerator: BigInt.from(rule.numerator),
        denominator: BigInt.from(rule.denominator),
        policy: policy,
      );
      taxes[rule.code] = tax;
      taxTotal = taxTotal + tax;
      if (!rule.inclusive) {
        exclusiveTaxTotal = exclusiveTaxTotal + tax;
      }
    }

    final total = subtotal + exclusiveTaxTotal;
    return TaxResult(
      subtotal: subtotal,
      taxes: taxes,
      taxTotal: taxTotal,
      total: total,
    );
  }
}

class TaxResult {
  const TaxResult({
    required this.subtotal,
    required this.taxes,
    required this.taxTotal,
    required this.total,
  });

  final Money subtotal;
  final Map<String, Money> taxes;
  final Money taxTotal;
  final Money total;
}
