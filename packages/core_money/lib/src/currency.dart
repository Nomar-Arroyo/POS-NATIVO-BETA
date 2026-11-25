class Currency {
  const Currency({
    required this.code,
    required this.minorUnitDigits,
  }) : assert(minorUnitDigits >= 0);

  final String code;
  final int minorUnitDigits;

  BigInt get minorUnitFactor => BigInt.from(10).pow(minorUnitDigits);

  static const Currency usd = Currency(code: 'USD', minorUnitDigits: 2);
  static const Currency ves = Currency(code: 'VES', minorUnitDigits: 2);

  @override
  bool operator ==(Object other) =>
      other is Currency &&
      code == other.code &&
      minorUnitDigits == other.minorUnitDigits;

  @override
  int get hashCode => Object.hash(code, minorUnitDigits);

  @override
  String toString() => code;
}
