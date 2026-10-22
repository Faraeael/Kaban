import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_tracker/models/app_settings.dart';
import 'package:finance_tracker/models/debt.dart';
import 'package:finance_tracker/models/salary_plan.dart';
import 'package:finance_tracker/screens/dashboard/widgets/paycheck_card.dart';
import 'package:finance_tracker/screens/dashboard/widgets/salary_plan_sheet.dart';
import 'package:finance_tracker/state/data_providers.dart';
import 'package:finance_tracker/state/finance_providers.dart';
import 'package:finance_tracker/state/settings_provider.dart';

class _FakeSettingsService extends SettingsService {
  AppSettings current;
  _FakeSettingsService(this.current);

  @override
  Future<AppSettings> load() async => current;

  @override
  Future<void> save(AppSettings s) async {
    current = s;
  }
}
class _FakeDebtListNotifier extends StateNotifier<List<Debt>> implements DebtListNotifier {
  _FakeDebtListNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}


void main() {
  group('PaycheckCard & SalaryPlanSheet Widget Tests', () {
    testWidgets('PaycheckCard shows prompt when no salary plan is configured',
        (tester) async {
      final fakeSettingsService = _FakeSettingsService(const AppSettings());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsServiceProvider.overrideWithValue(fakeSettingsService),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PaycheckCard(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Set Up Paycheck Plan'), findsOneWidget);
      expect(find.text('Configure'), findsOneWidget);
    });

    testWidgets('PaycheckCard shows Safe to Spend and obligations when plan configured',
        (tester) async {
      const plan = SalaryPlan(
        basicSalary: 50000,
        payFrequency: PayFrequency.biMonthly15_30,
      );

      final fakeSettingsService =
          _FakeSettingsService(const AppSettings(salaryPlan: plan));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) {
              final notifier = SettingsNotifier(fakeSettingsService);
              notifier.state = const AppSettings(salaryPlan: plan);
              return notifier;
            }),
            debtListProvider.overrideWith((ref) => _FakeDebtListNotifier(const [
                  Debt(
                    id: 'd1',
                    name: 'BDO Visa',
                    balance: 12000,
                    apr: 24,
                    minPayment: 3000,
                    strategy: DebtStrategy.avalanche,
                    dueDay: 20,
                  ),
                ])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PaycheckCard(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Safe to Spend'), findsOneWidget);
      expect(find.text('Net Payday'), findsOneWidget);
      expect(find.text('Debt Due'), findsOneWidget);
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
    });
    testWidgets('PaycheckCard renders at 360px viewport with 16px margins without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const plan = SalaryPlan(
        basicSalary: 50000,
        payFrequency: PayFrequency.biMonthly15_30,
      );
      final fakeSettingsService =
          _FakeSettingsService(const AppSettings(salaryPlan: plan));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) {
              final notifier = SettingsNotifier(fakeSettingsService);
              notifier.state = const AppSettings(salaryPlan: plan);
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: EdgeInsets.all(16),
                child: PaycheckCard(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Safe to Spend'), findsOneWidget);
    });

    testWidgets('PaycheckCard renders at 720px two-column viewport without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(720, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const plan = SalaryPlan(
        basicSalary: 50000,
        payFrequency: PayFrequency.biMonthly15_30,
      );
      final fakeSettingsService =
          _FakeSettingsService(const AppSettings(salaryPlan: plan));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) {
              final notifier = SettingsNotifier(fakeSettingsService);
              notifier.state = const AppSettings(salaryPlan: plan);
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: PaycheckCard(),
                    ),
                  ),
                  Expanded(child: SizedBox()),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Safe to Spend'), findsOneWidget);
    });


    testWidgets('SalaryPlanSheet renders and allows saving plan',
        (tester) async {
      final fakeSettingsService = _FakeSettingsService(const AppSettings());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsServiceProvider.overrideWithValue(fakeSettingsService),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SalaryPlanSheet(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Set Up Salary Plan'), findsOneWidget);
      expect(find.text('Monthly Basic Salary'), findsOneWidget);

      // Enter basic salary
      final salaryField = find.widgetWithText(TextField, 'Monthly Basic Salary');
      await tester.enterText(salaryField, '45000');
      await tester.pumpAndSettle();

      // Check live calculation updated
      expect(find.textContaining('SSS:'), findsOneWidget);
      expect(find.textContaining('Net Monthly Take-Home:'), findsOneWidget);

      // Save plan
      final saveBtn = find.text('Save Salary Plan');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(fakeSettingsService.current.salaryPlan, isNotNull);
      expect(fakeSettingsService.current.salaryPlan!.basicSalary, 45000.0);
    });

    testWidgets('SalaryPlanSheet supports Daily Rate (Arawan) and saves plan',
        (tester) async {
      final fakeSettingsService = _FakeSettingsService(const AppSettings());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsServiceProvider.overrideWithValue(fakeSettingsService),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SalaryPlanSheet(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Select Daily Rate segment
      final dailySegment = find.text('Daily Rate (Arawan)');
      await tester.ensureVisible(dailySegment);
      await tester.tap(dailySegment);
      await tester.pumpAndSettle();

      expect(find.text('Daily Rate'), findsOneWidget);
      expect(find.text('Days / Mo'), findsOneWidget);

      // Enter daily rate
      final dailyField = find.widgetWithText(TextField, 'Daily Rate');
      await tester.enterText(dailyField, '1000');
      await tester.pumpAndSettle();

      expect(find.textContaining('Equivalent monthly basic: ₱22,000.00'), findsOneWidget);

      // Save plan
      final saveBtn = find.text('Save Salary Plan');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      final saved = fakeSettingsService.current.salaryPlan;
      expect(saved, isNotNull);
      expect(saved!.rateType, SalaryRateType.daily);
      expect(saved.dailyRate, 1000.0);
      expect(saved.workDaysPerMonth, 22);
      expect(saved.basicSalary, 22000.0);
    });
  });
}
