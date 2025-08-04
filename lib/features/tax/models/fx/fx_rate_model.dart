import 'package:json_annotation/json_annotation.dart';

part 'fx_rate_model.g.dart';

enum Currency {
  sgd, // Singapore Dollar (base)
  usd, // US Dollar
  eur, // Euro
  gbp, // British Pound
  jpy, // Japanese Yen
  aud, // Australian Dollar
  cad, // Canadian Dollar
  chf, // Swiss Franc
  cny, // Chinese Yuan
  hkd, // Hong Kong Dollar
  inr, // Indian Rupee
  krw, // Korean Won
  myr, // Malaysian Ringgit
  thb, // Thai Baht
  idr, // Indonesian Rupiah
  php, // Philippine Peso
  vnd, // Vietnamese Dong
  nzd, // New Zealand Dollar
  nok, // Norwegian Krone
  sek, // Swedish Krona
  dkk, // Danish Krone
}

enum RateSource {
  masReferenceRate, // Monetary Authority of Singapore
  centralBank,
  commercialBank,
  fxProvider,
  manual,
  api,
}

enum RateType {
  spot,
  buying,
  selling,
  middle,
  reference,
  closing,
  average,
}

@JsonSerializable()
class FxRate {
  final String id;
  final Currency baseCurrency;
  final Currency targetCurrency;
  final double rate;
  final RateType rateType;
  final RateSource source;
  final DateTime effectiveDate;
  final DateTime timestamp;
  final String? sourceReference;
  final Map<String, dynamic>? metadata;

  const FxRate({
    required this.id,
    required this.baseCurrency,
    required this.targetCurrency,
    required this.rate,
    required this.rateType,
    required this.source,
    required this.effectiveDate,
    required this.timestamp,
    this.sourceReference,
    this.metadata,
  });

  factory FxRate.fromJson(Map<String, dynamic> json) => _$FxRateFromJson(json);
  Map<String, dynamic> toJson() => _$FxRateToJson(this);

  double convertAmount(double amount) {
    return amount * rate;
  }

  FxRate inverse() {
    return FxRate(
      id: '${id}_inverse',
      baseCurrency: targetCurrency,
      targetCurrency: baseCurrency,
      rate: 1.0 / rate,
      rateType: rateType,
      source: source,
      effectiveDate: effectiveDate,
      timestamp: timestamp,
      sourceReference: sourceReference,
      metadata: metadata,
    );
  }

  String get currencyPair =>
      '${baseCurrency.name.toUpperCase()}/${targetCurrency.name.toUpperCase()}';
}

@JsonSerializable()
class FxRateHistory {
  final Currency baseCurrency;
  final Currency targetCurrency;
  final List<FxRate> rates;
  final DateTime lastUpdated;

  const FxRateHistory({
    required this.baseCurrency,
    required this.targetCurrency,
    required this.rates,
    required this.lastUpdated,
  });

  factory FxRateHistory.fromJson(Map<String, dynamic> json) =>
      _$FxRateHistoryFromJson(json);
  Map<String, dynamic> toJson() => _$FxRateHistoryToJson(this);

  FxRate? getRateForDate(DateTime date, {RateType? preferredType}) {
    // Find the rate closest to the date
    FxRate? closestRate;
    Duration? closestDifference;

    for (final rate in rates) {
      if (preferredType != null && rate.rateType != preferredType) continue;

      final difference = date.difference(rate.effectiveDate).abs();

      if (closestRate == null || difference < closestDifference!) {
        closestRate = rate;
        closestDifference = difference;
      }
    }

    return closestRate;
  }

  List<FxRate> getRatesInPeriod(DateTime startDate, DateTime endDate) {
    return rates.where((rate) {
      return rate.effectiveDate.isAfter(startDate) &&
          rate.effectiveDate.isBefore(endDate);
    }).toList();
  }

  double? getAverageRateForPeriod(DateTime startDate, DateTime endDate) {
    final periodRates = getRatesInPeriod(startDate, endDate);
    if (periodRates.isEmpty) return null;

    final totalRate =
        periodRates.fold<double>(0, (sum, rate) => sum + rate.rate);
    return totalRate / periodRates.length;
  }
}

@JsonSerializable()
class CurrencyConversion {
  final String id;
  final Currency fromCurrency;
  final Currency toCurrency;
  final double originalAmount;
  final double convertedAmount;
  final double exchangeRate;
  final DateTime conversionDate;
  final RateSource rateSource;
  final String? transactionReference;
  final String? purpose;

  const CurrencyConversion({
    required this.id,
    required this.fromCurrency,
    required this.toCurrency,
    required this.originalAmount,
    required this.convertedAmount,
    required this.exchangeRate,
    required this.conversionDate,
    required this.rateSource,
    this.transactionReference,
    this.purpose,
  });

  factory CurrencyConversion.fromJson(Map<String, dynamic> json) =>
      _$CurrencyConversionFromJson(json);
  Map<String, dynamic> toJson() => _$CurrencyConversionToJson(this);
}

@JsonSerializable()
class TaxTreatyRate {
  final String treatyId;
  final String countryCode;
  final String countryName;
  final Currency currency;
  final Map<String, double>
      withholdingTaxRates; // e.g., {'dividends': 0.05, 'interest': 0.10}
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
  final Map<String, dynamic> specialProvisions;
  final String? treatyReference;

  const TaxTreatyRate({
    required this.treatyId,
    required this.countryCode,
    required this.countryName,
    required this.currency,
    required this.withholdingTaxRates,
    required this.effectiveFrom,
    this.effectiveTo,
    this.specialProvisions = const {},
    this.treatyReference,
  });

  factory TaxTreatyRate.fromJson(Map<String, dynamic> json) =>
      _$TaxTreatyRateFromJson(json);
  Map<String, dynamic> toJson() => _$TaxTreatyRateToJson(this);

  double? getWithholdingTaxRate(String incomeType) {
    return withholdingTaxRates[incomeType];
  }

  bool isEffectiveOn(DateTime date) {
    final isAfterStart =
        date.isAfter(effectiveFrom) || date.isAtSameMomentAs(effectiveFrom);
    final isBeforeEnd = effectiveTo == null || date.isBefore(effectiveTo!);
    return isAfterStart && isBeforeEnd;
  }
}

// Singapore-specific FX and international tax configurations
class SingaporeFxConfig {
  static const Currency baseCurrency = Currency.sgd;

  static final Map<Currency, String> currencyNames = {
    Currency.sgd: 'Singapore Dollar',
    Currency.usd: 'US Dollar',
    Currency.eur: 'Euro',
    Currency.gbp: 'British Pound Sterling',
    Currency.jpy: 'Japanese Yen',
    Currency.aud: 'Australian Dollar',
    Currency.cad: 'Canadian Dollar',
    Currency.chf: 'Swiss Franc',
    Currency.cny: 'Chinese Yuan Renminbi',
    Currency.hkd: 'Hong Kong Dollar',
    Currency.inr: 'Indian Rupee',
    Currency.krw: 'Korean Won',
    Currency.myr: 'Malaysian Ringgit',
    Currency.thb: 'Thai Baht',
    Currency.idr: 'Indonesian Rupiah',
    Currency.php: 'Philippine Peso',
    Currency.vnd: 'Vietnamese Dong',
    Currency.nzd: 'New Zealand Dollar',
    Currency.nok: 'Norwegian Krone',
    Currency.sek: 'Swedish Krona',
    Currency.dkk: 'Danish Krone',
  };

  static final Map<Currency, String> currencySymbols = {
    Currency.sgd: 'S\$',
    Currency.usd: 'US\$',
    Currency.eur: '€',
    Currency.gbp: '£',
    Currency.jpy: '¥',
    Currency.aud: 'A\$',
    Currency.cad: 'C\$',
    Currency.chf: 'CHF',
    Currency.cny: '¥',
    Currency.hkd: 'HK\$',
    Currency.inr: '₹',
    Currency.krw: '₩',
    Currency.myr: 'RM',
    Currency.thb: '฿',
    Currency.idr: 'Rp',
    Currency.php: '₱',
    Currency.vnd: '₫',
    Currency.nzd: 'NZ\$',
    Currency.nok: 'kr',
    Currency.sek: 'kr',
    Currency.dkk: 'kr',
  };

  // Sample historical rates (in real implementation, this would come from MAS or other sources)
  static final List<FxRate> sampleHistoricalRates = [
    FxRate(
      id: 'usd_sgd_2024_01',
      baseCurrency: Currency.usd,
      targetCurrency: Currency.sgd,
      rate: 1.3520,
      rateType: RateType.reference,
      source: RateSource.masReferenceRate,
      effectiveDate: DateTime(2024, 1, 1),
      timestamp: DateTime(2024, 1, 1, 9, 0),
      sourceReference: 'MAS Reference Rate',
    ),
    FxRate(
      id: 'eur_sgd_2024_01',
      baseCurrency: Currency.eur,
      targetCurrency: Currency.sgd,
      rate: 1.4820,
      rateType: RateType.reference,
      source: RateSource.masReferenceRate,
      effectiveDate: DateTime(2024, 1, 1),
      timestamp: DateTime(2024, 1, 1, 9, 0),
      sourceReference: 'MAS Reference Rate',
    ),
    FxRate(
      id: 'gbp_sgd_2024_01',
      baseCurrency: Currency.gbp,
      targetCurrency: Currency.sgd,
      rate: 1.7150,
      rateType: RateType.reference,
      source: RateSource.masReferenceRate,
      effectiveDate: DateTime(2024, 1, 1),
      timestamp: DateTime(2024, 1, 1, 9, 0),
      sourceReference: 'MAS Reference Rate',
    ),
  ];

  // Singapore's tax treaties and withholding tax rates
  static final List<TaxTreatyRate> taxTreatyRates = [
    TaxTreatyRate(
      treatyId: 'sg_us_treaty',
      countryCode: 'US',
      countryName: 'United States',
      currency: Currency.usd,
      withholdingTaxRates: {
        'dividends': 0.05, // 5% for substantial holdings
        'interest': 0.10, // 10%
        'royalties': 0.10, // 10%
      },
      effectiveFrom: DateTime(2000, 1, 1),
      specialProvisions: {
        'dividendsSubstantialHolding': 0.05, // 5% if 10% or more shareholding
        'dividendsOther': 0.15, // 15% otherwise
        'interestGovernment': 0.0, // 0% for government securities
      },
      treatyReference: 'Singapore-US DTA',
    ),
    TaxTreatyRate(
      treatyId: 'sg_uk_treaty',
      countryCode: 'GB',
      countryName: 'United Kingdom',
      currency: Currency.gbp,
      withholdingTaxRates: {
        'dividends': 0.05,
        'interest': 0.10,
        'royalties': 0.10,
      },
      effectiveFrom: DateTime(1997, 1, 1),
      treatyReference: 'Singapore-UK DTA',
    ),
    TaxTreatyRate(
      treatyId: 'sg_china_treaty',
      countryCode: 'CN',
      countryName: 'China',
      currency: Currency.cny,
      withholdingTaxRates: {
        'dividends': 0.05,
        'interest': 0.07,
        'royalties': 0.10,
      },
      effectiveFrom: DateTime(2009, 1, 1),
      treatyReference: 'Singapore-China DTA',
    ),
    TaxTreatyRate(
      treatyId: 'sg_india_treaty',
      countryCode: 'IN',
      countryName: 'India',
      currency: Currency.inr,
      withholdingTaxRates: {
        'dividends': 0.05,
        'interest': 0.10,
        'royalties': 0.10,
        'fees_for_technical_services': 0.10,
      },
      effectiveFrom: DateTime(1994, 1, 1),
      treatyReference: 'Singapore-India CECA',
    ),
  ];

  static String getCurrencyName(Currency currency) {
    return currencyNames[currency] ?? currency.name.toUpperCase();
  }

  static String getCurrencySymbol(Currency currency) {
    return currencySymbols[currency] ?? currency.name.toUpperCase();
  }

  static TaxTreatyRate? getTreatyRate(String countryCode, DateTime date) {
    return taxTreatyRates
        .where((treaty) =>
            treaty.countryCode == countryCode && treaty.isEffectiveOn(date))
        .firstOrNull;
  }

  static double? getWithholdingTaxRate(
      String countryCode, String incomeType, DateTime date) {
    final treaty = getTreatyRate(countryCode, date);
    return treaty?.getWithholdingTaxRate(incomeType);
  }

  static List<Currency> getSupportedCurrencies() {
    return Currency.values;
  }

  static List<String> getAvailableCountries() {
    return taxTreatyRates.map((treaty) => treaty.countryName).toList();
  }
}
