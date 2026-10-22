import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/salary_plan.dart';
import '../../../services/ph_statutory_service.dart';
import '../../../state/settings_provider.dart';
import '../../../utils/formatters.dart';

void showSalaryPlanSheet(BuildContext context, {SalaryPlan? initial}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => SalaryPlanSheet(initial: initial),
  );
}

class SalaryPlanSheet extends ConsumerStatefulWidget {
  final SalaryPlan? initial;

  const SalaryPlanSheet({super.key, this.initial});

  @override
  ConsumerState<SalaryPlanSheet> createState() => _SalaryPlanSheetState();
}

class _SalaryPlanSheetState extends ConsumerState<SalaryPlanSheet> {
  late final TextEditingController _basicSalaryCtrl;
  late final TextEditingController _dailyRateCtrl;
  late final TextEditingController _workDaysCtrl;
  late final TextEditingController _allowancesCtrl;
  late final TextEditingController _sssCtrl;
  late final TextEditingController _philHealthCtrl;
  late final TextEditingController _pagIbigCtrl;
  late final TextEditingController _taxCtrl;
  late final TextEditingController _otherCtrl;

  late PayFrequency _frequency;
  late SalaryRateType _rateType;
  late bool _autoCalculate;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _frequency = p?.payFrequency ?? PayFrequency.biMonthly15_30;
    _rateType = p?.rateType ?? SalaryRateType.monthly;
    _autoCalculate = p?.autoCalculateDeductions ?? true;

    _basicSalaryCtrl = TextEditingController(
      text: p != null && p.basicSalary > 0 ? formatInputAmount(p.basicSalary) : '',
    );
    _dailyRateCtrl = TextEditingController(
      text: p?.dailyRate != null && p!.dailyRate! > 0 ? formatInputAmount(p.dailyRate) : '',
    );
    _workDaysCtrl = TextEditingController(
      text: (p?.workDaysPerMonth ?? 22).toString(),
    );
    _allowancesCtrl = TextEditingController(
      text: p != null && p.allowances > 0 ? formatInputAmount(p.allowances) : '',
    );
    _sssCtrl = TextEditingController(
      text: p?.customSss != null ? formatInputAmount(p!.customSss) : '',
    );
    _philHealthCtrl = TextEditingController(
      text: p?.customPhilHealth != null ? formatInputAmount(p!.customPhilHealth) : '',
    );
    _pagIbigCtrl = TextEditingController(
      text: p?.customPagIbig != null ? formatInputAmount(p!.customPagIbig) : '',
    );
    _taxCtrl = TextEditingController(
      text: p?.customTax != null ? formatInputAmount(p!.customTax) : '',
    );
    _otherCtrl = TextEditingController(
      text: p?.otherDeductions != null ? formatInputAmount(p!.otherDeductions) : '',
    );
  }

  @override
  void dispose() {
    _basicSalaryCtrl.dispose();
    _dailyRateCtrl.dispose();
    _workDaysCtrl.dispose();
    _allowancesCtrl.dispose();
    _sssCtrl.dispose();
    _philHealthCtrl.dispose();
    _pagIbigCtrl.dispose();
    _taxCtrl.dispose();
    _otherCtrl.dispose();
    super.dispose();
  }

  double _parse(TextEditingController ctrl) {
    return double.tryParse(ctrl.text.replaceAll(',', '').trim()) ?? 0.0;
  }

  double? _parseNullable(TextEditingController ctrl) {
    final t = ctrl.text.replaceAll(',', '').trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  StatutoryBreakdown _computeBreakdown() {
    final double basic;
    if (_rateType == SalaryRateType.daily) {
      final daily = _parse(_dailyRateCtrl);
      final days = _parseNullable(_workDaysCtrl) ?? 22.0;
      basic = daily * days;
    } else {
      basic = _parse(_basicSalaryCtrl);
    }
    final allowances = _parse(_allowancesCtrl);
    final other = _parseNullable(_otherCtrl);

    if (_autoCalculate) {
      return PhStatutoryService.calculateDeductions(
        basicSalary: basic,
        allowances: allowances,
        otherDeductions: other,
      );
    }

    return PhStatutoryService.calculateDeductions(
      basicSalary: basic,
      allowances: allowances,
      overrideSss: _parseNullable(_sssCtrl),
      overridePhilHealth: _parseNullable(_philHealthCtrl),
      overridePagIbig: _parseNullable(_pagIbigCtrl),
      overrideTax: _parseNullable(_taxCtrl),
      otherDeductions: other,
    );
  }

  void _save() {
    final double basic;
    final double? daily;
    final int? days;

    if (_rateType == SalaryRateType.daily) {
      daily = _parse(_dailyRateCtrl);
      days = (_parseNullable(_workDaysCtrl) ?? 22.0).toInt();
      if (daily <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid daily rate.')),
        );
        return;
      }
      basic = daily * days;
    } else {
      basic = _parse(_basicSalaryCtrl);
      daily = null;
      days = null;
      if (basic <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid monthly basic salary.')),
        );
        return;
      }
    }

    final allowances = _parse(_allowancesCtrl);
    final plan = SalaryPlan(
      basicSalary: basic,
      allowances: allowances,
      payFrequency: _frequency,
      rateType: _rateType,
      dailyRate: daily,
      workDaysPerMonth: days,
      autoCalculateDeductions: _autoCalculate,
      customSss: _autoCalculate ? null : _parseNullable(_sssCtrl),
      customPhilHealth: _autoCalculate ? null : _parseNullable(_philHealthCtrl),
      customPagIbig: _autoCalculate ? null : _parseNullable(_pagIbigCtrl),
      customTax: _autoCalculate ? null : _parseNullable(_taxCtrl),
      otherDeductions: _parseNullable(_otherCtrl),
    );

    final currentSettings = ref.read(settingsProvider);
    ref.read(settingsProvider.notifier).update(
          currentSettings.copyWith(salaryPlan: plan),
        );

    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
  }

  void _remove() {
    final currentSettings = ref.read(settingsProvider);
    ref.read(settingsProvider.notifier).update(
          currentSettings.copyWith(clearSalaryPlan: true),
        );
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final breakdown = _computeBreakdown();
    final divisor = _frequency == PayFrequency.biMonthly15_30 ? 2 : 1;
    final netPerPayday = breakdown.netMonthlyIncome / divisor;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.initial == null ? 'Set Up Salary Plan' : 'Edit Salary Plan',
                  style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (widget.initial != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Remove Plan',
                    onPressed: _remove,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Configure your basic salary (monthly or daily rate) and statutory contributions (SSS, PhilHealth, Pag-IBIG, Tax) to track take-home pay and safe-to-spend.',
              style: t.textTheme.bodyMedium?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            // Rate Type Selector (Monthly vs Daily)
            Text('Salary Rate Type', style: t.textTheme.labelLarge),
            const SizedBox(height: 6),
            SegmentedButton<SalaryRateType>(
              segments: const [
                ButtonSegment(
                  value: SalaryRateType.monthly,
                  label: Text('Monthly Salary'),
                  icon: Icon(Icons.calendar_month_outlined),
                ),
                ButtonSegment(
                  value: SalaryRateType.daily,
                  label: Text('Daily Rate (Arawan)'),
                  icon: Icon(Icons.today_outlined),
                ),
              ],
              selected: {_rateType},
              onSelectionChanged: (set) {
                setState(() => _rateType = set.first);
              },
            ),
            const SizedBox(height: 16),
            // Frequency Selector
            Text('Pay Frequency', style: t.textTheme.labelLarge),
            const SizedBox(height: 6),
            SegmentedButton<PayFrequency>(
              segments: const [
                ButtonSegment(
                  value: PayFrequency.biMonthly15_30,
                  label: Text('15th & 30th (Quincena)'),
                  icon: Icon(Icons.calendar_view_week_rounded),
                ),
                ButtonSegment(
                  value: PayFrequency.monthly,
                  label: Text('Monthly'),
                  icon: Icon(Icons.calendar_month_rounded),
                ),
              ],
              selected: {_frequency},
              onSelectionChanged: (set) {
                setState(() => _frequency = set.first);
              },
            ),
            const SizedBox(height: 16),
            // Salary Inputs depending on Rate Type
            if (_rateType == SalaryRateType.daily) ...[
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _dailyRateCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Daily Rate',
                        prefixText: '₱ ',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _workDaysCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Days / Mo',
                        suffixText: 'days',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Builder(
                builder: (_) {
                  final daily = _parse(_dailyRateCtrl);
                  final days = _parseNullable(_workDaysCtrl) ?? 22.0;
                  final computed = daily * days;
                  return Text(
                    daily > 0
                        ? 'Equivalent monthly basic: ${peso(computed)} (${pesoExact(daily)} × ${days.toStringAsFixed(0)} days)'
                        : 'Standard: 22 days (5-day work week) or 26 days (6-day work week)',
                    style: t.textTheme.labelSmall?.copyWith(
                      color: t.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _allowancesCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Monthly Allowances (Optional)',
                  prefixText: '₱ ',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _basicSalaryCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Monthly Basic Salary',
                        prefixText: '₱ ',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _allowancesCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Allowances (Optional)',
                        prefixText: '₱ ',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            // Auto Calculate Switch
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto-calculate PH Deductions', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('2025/2026 SSS, PhilHealth, Pag-IBIG, and BIR TRAIN tax'),
              value: _autoCalculate,
              onChanged: (val) {
                setState(() {
                  _autoCalculate = val;
                  if (!val) {
                    if (_sssCtrl.text.isEmpty) _sssCtrl.text = formatInputAmount(breakdown.sss);
                    if (_philHealthCtrl.text.isEmpty) _philHealthCtrl.text = formatInputAmount(breakdown.philHealth);
                    if (_pagIbigCtrl.text.isEmpty) _pagIbigCtrl.text = formatInputAmount(breakdown.pagIbig);
                    if (_taxCtrl.text.isEmpty) _taxCtrl.text = formatInputAmount(breakdown.tax);
                  }
                });
              },
            ),
            if (!_autoCalculate) ...[
              const SizedBox(height: 8),
              Text(
                'Manual Deductions Override (Monthly)',
                style: t.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: t.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _sssCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'SSS Share', prefixText: '₱ '),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _philHealthCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'PhilHealth', prefixText: '₱ '),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _pagIbigCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Pag-IBIG', prefixText: '₱ '),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _taxCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Withholding Tax', prefixText: '₱ '),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _otherCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Other Monthly Deductions (e.g. HMO, Loans)',
                prefixText: '₱ ',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            // Breakdown Card Live Preview
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: t.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: t.colorScheme.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('SSS: ${peso(breakdown.sss)}', style: t.textTheme.bodySmall),
                      Text('PhilHealth: ${peso(breakdown.philHealth)}', style: t.textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Pag-IBIG: ${peso(breakdown.pagIbig)}', style: t.textTheme.bodySmall),
                      Text('BIR Tax: ${peso(breakdown.tax)}', style: t.textTheme.bodySmall),
                    ],
                  ),
                  if (breakdown.other > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Other Deductions: ${peso(breakdown.other)}', style: t.textTheme.bodySmall),
                        const SizedBox.shrink(),
                      ],
                    ),
                  ],
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Deductions:', style: t.textTheme.labelMedium),
                      Text(peso(breakdown.totalDeductions),
                          style: t.textTheme.labelMedium?.copyWith(
                            color: t.colorScheme.error,
                            fontWeight: FontWeight.bold,
                          )),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Net Monthly Take-Home:', style: t.textTheme.titleSmall),
                      Text(peso(breakdown.netMonthlyIncome),
                          style: t.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: t.colorScheme.primary,
                          )),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _frequency == PayFrequency.biMonthly15_30
                            ? 'Net Per Paycheck (Quincena):'
                            : 'Net Per Paycheck:',
                        style: t.textTheme.labelMedium,
                      ),
                      Text(peso(netPerPayday),
                          style: t.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: t.colorScheme.secondary,
                          )),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Save Salary Plan'),
              onPressed: _save,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
