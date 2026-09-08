import 'package:flutter_test/flutter_test.dart';
import 'package:finance_tracker/models/quick_preset.dart';
import 'package:finance_tracker/services/coach_actions.dart';

void main() {
  group('QuickPreset model', () {
    test('serializes to and from Map/JSON correctly', () {
      const preset = QuickPreset(
        id: 'jeep13',
        icon: '🚐',
        label: 'Jeep',
        amount: 13.0,
        category: 'Transport',
        walletId: 'wallet-1',
      );

      final jsonStr = preset.toJson();
      final restored = QuickPreset.fromJson(jsonStr);

      expect(restored.id, equals('jeep13'));
      expect(restored.icon, equals('🚐'));
      expect(restored.label, equals('Jeep'));
      expect(restored.amount, equals(13.0));
      expect(restored.category, equals('Transport'));
      expect(restored.walletId, equals('wallet-1'));
    });

    test('copyWith modifies fields properly', () {
      const preset = QuickPreset(
        id: 'coffee120',
        icon: '☕',
        label: 'Coffee',
        amount: 120.0,
        category: 'Food',
      );

      final updated = preset.copyWith(
        amount: 140.0,
        label: 'Iced Coffee',
      );

      expect(updated.id, equals('coffee120'));
      expect(updated.amount, equals(140.0));
      expect(updated.label, equals('Iced Coffee'));
      expect(updated.icon, equals('☕'));
      expect(updated.category, equals('Food'));
    });

    test('default presets contains the 5 expected presets', () {
      expect(kDefaultQuickPresets.length, equals(5));
      expect(
          kDefaultQuickPresets.any((p) => p.label == 'Jeep' && p.amount == 13),
          isTrue);
      expect(
          kDefaultQuickPresets.any((p) => p.label == 'Jeep+' && p.amount == 15),
          isTrue);
      expect(
          kDefaultQuickPresets.any((p) => p.label == 'Trike' && p.amount == 25),
          isTrue);
      expect(
          kDefaultQuickPresets
              .any((p) => p.label == 'Coffee' && p.amount == 120),
          isTrue);
      expect(
          kDefaultQuickPresets
              .any((p) => p.label == 'Lunch' && p.amount == 150),
          isTrue);
    });
  });

  group('Action validator with image attachments', () {
    test(
        'accepts expense action from multimodal vision even when user text has no numbers or merchant',
        () {
      const action = LogTransactionAction(
        amount: 450.0,
        isIncome: false,
        category: 'Food',
        note: 'Jollibee',
        walletName: 'GCash',
      );

      // User sends an image with caption "scan this receipt" or empty text
      final result = validateAgainstUserMessage(
        actions: [action],
        userMessage: 'scan this receipt',
        hasImageAttachment: true,
      );

      expect(result.actions.length, equals(1));
      final validated = result.actions.first as LogTransactionAction;
      expect(validated.amount, equals(450.0));
      expect(validated.note, equals('Jollibee'));
      expect(validated.walletName, equals('GCash'));
    });

    test(
        'regular text without image still rejects numbers not mentioned by user',
        () {
      const action = LogTransactionAction(
        amount: 450.0,
        isIncome: false,
        category: 'Food',
        note: 'Jollibee',
      );

      // Without image attachment, safety validator drops hallucinated amounts
      final result = validateAgainstUserMessage(
        actions: [action],
        userMessage: 'Paid 50 for snack',
        hasImageAttachment: false,
      );

      expect(result.actions, isEmpty);
    });
  });
}
