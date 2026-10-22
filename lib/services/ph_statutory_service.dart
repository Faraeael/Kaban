class StatutoryBreakdown {
  final double sss;
  final double philHealth;
  final double pagIbig;
  final double taxableIncome;
  final double tax;
  final double other;
  final double totalDeductions;
  final double netMonthlyIncome;

  const StatutoryBreakdown({
    required this.sss,
    required this.philHealth,
    required this.pagIbig,
    required this.taxableIncome,
    required this.tax,
    required this.other,
    required this.totalDeductions,
    required this.netMonthlyIncome,
  });

  Map<String, dynamic> toJson() => {
        'sss': sss,
        'philHealth': philHealth,
        'pagIbig': pagIbig,
        'taxableIncome': taxableIncome,
        'tax': tax,
        'other': other,
        'totalDeductions': totalDeductions,
        'netMonthlyIncome': netMonthlyIncome,
      };

  factory StatutoryBreakdown.fromJson(Map<String, dynamic> json) =>
      StatutoryBreakdown(
        sss: (json['sss'] as num?)?.toDouble() ?? 0.0,
        philHealth: (json['philHealth'] as num?)?.toDouble() ?? 0.0,
        pagIbig: (json['pagIbig'] as num?)?.toDouble() ?? 0.0,
        taxableIncome: (json['taxableIncome'] as num?)?.toDouble() ?? 0.0,
        tax: (json['tax'] as num?)?.toDouble() ?? 0.0,
        other: (json['other'] as num?)?.toDouble() ?? 0.0,
        totalDeductions: (json['totalDeductions'] as num?)?.toDouble() ?? 0.0,
        netMonthlyIncome: (json['netMonthlyIncome'] as num?)?.toDouble() ?? 0.0,
      );
}

class PhStatutoryService {
  const PhStatutoryService._();

  /// SSS Employee Contribution (2025/2026: 5% employee share, min MSC ₱5,000, max MSC ₱35,000).
  static double calculateSss(double monthlyBasicSalary) {
    if (monthlyBasicSalary <= 0) return 0.0;
    if (monthlyBasicSalary < 5250) return 5000 * 0.05; // ₱250
    if (monthlyBasicSalary >= 34750) return 35000 * 0.05; // ₱1,750

    final step = ((monthlyBasicSalary - 4750) / 500).floor();
    final msc = 5000 + (step * 500);
    return msc * 0.05;
  }

  /// PhilHealth Employee Share (Circular PA2025-0002: 2.5% employee share, floor ₱10k, cap ₱100k).
  static double calculatePhilHealth(double monthlyBasicSalary) {
    if (monthlyBasicSalary <= 0) return 0.0;
    final clamped = monthlyBasicSalary.clamp(10000.0, 100000.0);
    return clamped * 0.025;
  }

  /// Pag-IBIG (HDMF) Employee Share (1% <= ₱1,500; 2% > ₱1,500; capped at ₱10k base -> ₱200/mo).
  static double calculatePagIbig(double monthlyBasicSalary) {
    if (monthlyBasicSalary <= 0) return 0.0;
    if (monthlyBasicSalary <= 1500) return monthlyBasicSalary * 0.01;
    final clamped = monthlyBasicSalary.clamp(0.0, 10000.0);
    return clamped * 0.02;
  }

  /// BIR RR 11-2018 Annex E (TRAIN Law) monthly withholding tax table.
  static double calculateWithholdingTax(double taxableIncome) {
    if (taxableIncome <= 20833.0) return 0.0;
    if (taxableIncome <= 33333.0) {
      return (taxableIncome - 20833.0) * 0.15;
    }
    if (taxableIncome <= 66667.0) {
      return 1875.0 + ((taxableIncome - 33333.0) * 0.20);
    }
    if (taxableIncome <= 166667.0) {
      return 8541.80 + ((taxableIncome - 66667.0) * 0.25);
    }
    if (taxableIncome <= 666667.0) {
      return 33541.80 + ((taxableIncome - 166667.0) * 0.30);
    }
    return 183541.80 + ((taxableIncome - 666667.0) * 0.35);
  }

  /// Calculates statutory contributions and net income with optional manual overrides.
  static StatutoryBreakdown calculateDeductions({
    required double basicSalary,
    double allowances = 0.0,
    double? overrideSss,
    double? overridePhilHealth,
    double? overridePagIbig,
    double? overrideTax,
    double? otherDeductions,
  }) {
    final sss = overrideSss ?? calculateSss(basicSalary);
    final philHealth = overridePhilHealth ?? calculatePhilHealth(basicSalary);
    final pagIbig = overridePagIbig ?? calculatePagIbig(basicSalary);

    // Statutory deductions are tax-exempt
    final grossIncome = basicSalary + allowances;
    final mandatoryStatutory = sss + philHealth + pagIbig;
    final taxableIncome = (grossIncome - mandatoryStatutory).clamp(0.0, double.infinity);

    final tax = overrideTax ?? calculateWithholdingTax(taxableIncome);
    final other = otherDeductions ?? 0.0;

    final totalDeductions = sss + philHealth + pagIbig + tax + other;
    final netMonthlyIncome = grossIncome - totalDeductions;

    return StatutoryBreakdown(
      sss: sss,
      philHealth: philHealth,
      pagIbig: pagIbig,
      taxableIncome: taxableIncome,
      tax: tax,
      other: other,
      totalDeductions: totalDeductions,
      netMonthlyIncome: netMonthlyIncome,
    );
  }
}
