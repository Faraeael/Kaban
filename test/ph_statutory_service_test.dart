import 'package:flutter_test/flutter_test.dart';
import 'package:finance_tracker/services/ph_statutory_service.dart';

void main() {
  group('PhStatutoryService', () {
    test('SSS calculation matches 2025/2026 brackets and caps', () {
      expect(PhStatutoryService.calculateSss(0), 0.0);
      expect(PhStatutoryService.calculateSss(4000), 250.0); // min MSC 5000 * 5%
      expect(PhStatutoryService.calculateSss(15000), 750.0); // MSC 15000 * 5%
      expect(PhStatutoryService.calculateSss(34750), 1750.0); // max MSC 35000 * 5%
      expect(PhStatutoryService.calculateSss(45000), 1750.0); // capped at 1750
    });

    test('PhilHealth calculation handles floor, cap, and rate', () {
      expect(PhStatutoryService.calculatePhilHealth(0), 0.0);
      expect(PhStatutoryService.calculatePhilHealth(8000), 250.0); // floor 10k * 2.5%
      expect(PhStatutoryService.calculatePhilHealth(15000), 375.0); // 15k * 2.5%
      expect(PhStatutoryService.calculatePhilHealth(45000), 1125.0); // 45k * 2.5%
      expect(PhStatutoryService.calculatePhilHealth(120000), 2500.0); // cap 100k * 2.5%
    });

    test('Pag-IBIG calculation handles below and above 1500 and cap', () {
      expect(PhStatutoryService.calculatePagIbig(0), 0.0);
      expect(PhStatutoryService.calculatePagIbig(1500), 15.0); // 1%
      expect(PhStatutoryService.calculatePagIbig(5000), 100.0); // 2%
      expect(PhStatutoryService.calculatePagIbig(25000), 200.0); // cap 10k * 2% = 200
    });

    test('TRAIN withholding tax computes progressive brackets correctly', () {
      expect(PhStatutoryService.calculateWithholdingTax(18000), 0.0);
      expect(PhStatutoryService.calculateWithholdingTax(20833), 0.0);

      // Bracket 2: 20,833 - 33,333 @ 15%
      final tax30k = PhStatutoryService.calculateWithholdingTax(30000);
      expect(tax30k, closeTo((30000 - 20833) * 0.15, 0.01));

      // Bracket 3: 33,333 - 66,667 @ 1,875 + 20%
      final tax45k = PhStatutoryService.calculateWithholdingTax(45000);
      expect(tax45k, closeTo(1875.0 + ((45000 - 33333) * 0.20), 0.01));
    });

    test('calculateDeductions combines mandatory deductions and tax correctly', () {
      final breakdown = PhStatutoryService.calculateDeductions(
        basicSalary: 45000,
        allowances: 5000,
      );

      expect(breakdown.sss, 1750.0);
      expect(breakdown.philHealth, 1125.0);
      expect(breakdown.pagIbig, 200.0);

      // Gross: 50,000. Statutory non-taxable: 3,075. Taxable: 46,925
      expect(breakdown.taxableIncome, 46925.0);
      expect(breakdown.tax, closeTo(1875.0 + ((46925.0 - 33333.0) * 0.20), 0.01));

      final expectedTotal = breakdown.sss + breakdown.philHealth + breakdown.pagIbig + breakdown.tax;
      expect(breakdown.totalDeductions, closeTo(expectedTotal, 0.01));
      expect(breakdown.netMonthlyIncome, closeTo(50000.0 - breakdown.totalDeductions, 0.01));
    });

    test('calculateDeductions respects manual overrides', () {
      final breakdown = PhStatutoryService.calculateDeductions(
        basicSalary: 45000,
        overrideSss: 1500,
        overridePhilHealth: 1000,
        overridePagIbig: 100,
        overrideTax: 3000,
        otherDeductions: 500,
      );

      expect(breakdown.sss, 1500.0);
      expect(breakdown.philHealth, 1000.0);
      expect(breakdown.pagIbig, 100.0);
      expect(breakdown.tax, 3000.0);
      expect(breakdown.other, 500.0);
      expect(breakdown.totalDeductions, 6100.0);
      expect(breakdown.netMonthlyIncome, 45000.0 - 6100.0);
    });
  });
}
