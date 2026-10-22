import '../services/ph_statutory_service.dart';

enum PayFrequency {
  monthly,
  biMonthly15_30,
}

enum SalaryRateType {
  monthly,
  daily,
}

class SalaryPlan {
  final double basicSalary;
  final double allowances;
  final PayFrequency payFrequency;
  final SalaryRateType rateType;
  final double? dailyRate;
  final int? workDaysPerMonth;
  final bool autoCalculateDeductions;
  final double? customSss;
  final double? customPhilHealth;
  final double? customPagIbig;
  final double? customTax;
  final double? otherDeductions;

  const SalaryPlan({
    required this.basicSalary,
    this.allowances = 0.0,
    this.payFrequency = PayFrequency.biMonthly15_30,
    this.rateType = SalaryRateType.monthly,
    this.dailyRate,
    this.workDaysPerMonth,
    this.autoCalculateDeductions = true,
    this.customSss,
    this.customPhilHealth,
    this.customPagIbig,
    this.customTax,
    this.otherDeductions,
  });

  double get effectiveMonthlyBasic =>
      rateType == SalaryRateType.daily && dailyRate != null && dailyRate! > 0
          ? (dailyRate! * (workDaysPerMonth ?? 22))
          : basicSalary;

  StatutoryBreakdown computeBreakdown() {
    final effectiveBasic = effectiveMonthlyBasic;
    if (autoCalculateDeductions) {
      return PhStatutoryService.calculateDeductions(
        basicSalary: effectiveBasic,
        allowances: allowances,
        otherDeductions: otherDeductions,
      );
    }
    return PhStatutoryService.calculateDeductions(
      basicSalary: effectiveBasic,
      allowances: allowances,
      overrideSss: customSss,
      overridePhilHealth: customPhilHealth,
      overridePagIbig: customPagIbig,
      overrideTax: customTax,
      otherDeductions: otherDeductions,
    );
  }

  Map<String, dynamic> toJson() => {
        'basicSalary': basicSalary,
        'allowances': allowances,
        'payFrequency': payFrequency.name,
        'rateType': rateType.name,
        'dailyRate': dailyRate,
        'workDaysPerMonth': workDaysPerMonth,
        'autoCalculateDeductions': autoCalculateDeductions,
        'customSss': customSss,
        'customPhilHealth': customPhilHealth,
        'customPagIbig': customPagIbig,
        'customTax': customTax,
        'otherDeductions': otherDeductions,
      };

  factory SalaryPlan.fromJson(Map<String, dynamic> json) => SalaryPlan(
        basicSalary: (json['basicSalary'] as num?)?.toDouble() ?? 0.0,
        allowances: (json['allowances'] as num?)?.toDouble() ?? 0.0,
        payFrequency: PayFrequency.values.firstWhere(
          (e) => e.name == json['payFrequency'],
          orElse: () => PayFrequency.biMonthly15_30,
        ),
        rateType: SalaryRateType.values.firstWhere(
          (e) => e.name == json['rateType'],
          orElse: () => SalaryRateType.monthly,
        ),
        dailyRate: (json['dailyRate'] as num?)?.toDouble(),
        workDaysPerMonth: json['workDaysPerMonth'] as int? ?? 22,
        autoCalculateDeductions:
            json['autoCalculateDeductions'] as bool? ?? true,
        customSss: (json['customSss'] as num?)?.toDouble(),
        customPhilHealth: (json['customPhilHealth'] as num?)?.toDouble(),
        customPagIbig: (json['customPagIbig'] as num?)?.toDouble(),
        customTax: (json['customTax'] as num?)?.toDouble(),
        otherDeductions: (json['otherDeductions'] as num?)?.toDouble(),
      );

  SalaryPlan copyWith({
    double? basicSalary,
    double? allowances,
    PayFrequency? payFrequency,
    SalaryRateType? rateType,
    double? dailyRate,
    int? workDaysPerMonth,
    bool? autoCalculateDeductions,
    double? customSss,
    double? customPhilHealth,
    double? customPagIbig,
    double? customTax,
    double? otherDeductions,
  }) =>
      SalaryPlan(
        basicSalary: basicSalary ?? this.basicSalary,
        allowances: allowances ?? this.allowances,
        payFrequency: payFrequency ?? this.payFrequency,
        rateType: rateType ?? this.rateType,
        dailyRate: dailyRate ?? this.dailyRate,
        workDaysPerMonth: workDaysPerMonth ?? this.workDaysPerMonth,
        autoCalculateDeductions:
            autoCalculateDeductions ?? this.autoCalculateDeductions,
        customSss: customSss ?? this.customSss,
        customPhilHealth: customPhilHealth ?? this.customPhilHealth,
        customPagIbig: customPagIbig ?? this.customPagIbig,
        customTax: customTax ?? this.customTax,
        otherDeductions: otherDeductions ?? this.otherDeductions,
      );
}
