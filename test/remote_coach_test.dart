import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_tracker/data/database.dart';
import 'package:finance_tracker/models/app_settings.dart';
import 'package:finance_tracker/models/chat_message.dart';
import 'package:finance_tracker/services/ai/ai_provider_config.dart';
import 'package:finance_tracker/services/ai/coach_service.dart';
import 'package:finance_tracker/services/ai/remote_coach.dart';
import 'package:finance_tracker/services/coach_actions.dart';
import 'package:finance_tracker/state/data_providers.dart';
import 'package:finance_tracker/state/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
void main() {
  group('RemoteCoach Conversation Memory & JSON Schema Preservation', () {
    late RemoteCoach coach;

    setUp(() {
      coach = RemoteCoach(
        config: kAIProviders[AIProvider.openrouter]!,
        apiKey: 'test-key',
        baseUrl: 'https://api.openai.com/v1',
        model: 'gpt-4o-mini',
        useActionSchema: true,
      );
    });

    test(
        'preserves full JSON envelope in conversation history (does not strip to plain text)',
        () {
      const userMsg = 'Paid PHP13 to Jeep put it under Cash';
      const rawAiResponse = '''
{
  "reply": "Logged ₱13 for your Jeep commute under Cash.",
  "actions": [
    {
      "type": "log_expense",
      "amount": 13,
      "category": "Transport",
      "wallet_name": "Cash",
      "note": "Jeep"
    }
  ]
}''';

      final reply = coach.parseEnvelopeForTesting(rawAiResponse, userMsg);
      expect(reply.actions.length, 1);
      expect(reply.actions.first, isA<LogTransactionAction>());
      expect(reply.text, 'Logged ₱13 for your Jeep commute under Cash.');

      // Record the turn in conversation
      coach.recordAssistantTurnForTesting(rawAiResponse, reply);

      // Verify conversation has NOT stripped the actions
      expect(coach.conversation.length, 1);
      final storedContent = coach.conversation.first.content;
      expect(storedContent, contains('"actions"'));
      expect(storedContent, contains('"type": "log_expense"'));
      expect(storedContent, contains('13'));

      // Must be valid JSON
      final decoded = json.decode(storedContent);
      expect(decoded['reply'], 'Logged ₱13 for your Jeep commute under Cash.');
      expect((decoded['actions'] as List).length, 1);
    });

    test('retains JSON schema across consecutive turns without degradation',
        () {
      // Turn 1: Jeep 13
      const userTurn1 = 'Paid PHP13 to Jeep put it under Cash';
      coach.conversation.add((role: 'user', content: userTurn1));

      const aiTurn1 = '''
{
  "reply": "Prepared a card for ₱13 Jeep fare.",
  "actions": [
    { "type": "log_expense", "amount": 13, "category": "Transport", "wallet_name": "Cash" }
  ]
}''';
      final reply1 = coach.parseEnvelopeForTesting(aiTurn1, userTurn1);
      coach.recordAssistantTurnForTesting(aiTurn1, reply1);

      // Turn 2: Jeep 15 (the scenario that previously broke)
      const userTurn2 = 'paid again to a jeep 15PHP this time';
      coach.conversation.add((role: 'user', content: userTurn2));

      const aiTurn2 = '''
{
  "reply": "Prepared a card for your second Jeep fare of ₱15.",
  "actions": [
    { "type": "log_expense", "amount": 15, "category": "Transport" }
  ]
}''';
      final reply2 = coach.parseEnvelopeForTesting(aiTurn2, userTurn2);
      coach.recordAssistantTurnForTesting(aiTurn2, reply2);

      expect(coach.conversation.length, 4);
      // Verify both assistant turns retain valid JSON schema
      final assistantTurns =
          coach.conversation.where((m) => m.role == 'assistant').toList();
      expect(assistantTurns.length, 2);

      for (final turn in assistantTurns) {
        expect(() => json.decode(turn.content), returnsNormally);
        final decoded = json.decode(turn.content) as Map<String, dynamic>;
        expect(decoded.containsKey('reply'), isTrue);
        expect(decoded.containsKey('actions'), isTrue);
        expect((decoded['actions'] as List).isNotEmpty, isTrue);
      }
    });

    test(
        'wraps plain text assistant response in JSON envelope so history remains consistent',
        () {
      const rawPlain =
          'Sure, here is some general budgeting advice for your debts.';
      final reply = coach.parseEnvelopeForTesting(rawPlain, 'Help me budget');

      coach.recordAssistantTurnForTesting(rawPlain, reply);

      expect(coach.conversation.length, 1);
      final storedContent = coach.conversation.first.content;
      final decoded = json.decode(storedContent) as Map<String, dynamic>;
      expect(decoded['reply'], rawPlain);
      expect(decoded['actions'], isEmpty);
    });

    test('parses markdown fenced json responses cleanly', () {
      const fencedResponse = '''```json
{
  "reply": "Adding your ₱15 transport expense.",
  "actions": [
    { "type": "log_expense", "amount": 15, "category": "Transport" }
  ]
}
```''';
      final reply =
          coach.parseEnvelopeForTesting(fencedResponse, 'Paid 15 for jeep');
      expect(reply.text, 'Adding your ₱15 transport expense.');
      expect(reply.actions.length, 1);
      expect((reply.actions.first as LogTransactionAction).amount, 15);

      // Even if the model included leading text before ```json,
      // recordAssistantTurn preserves the parsed actions in conversation.
      const prefixedResponse = '''Sure! Here is your card:
```json
{
  "reply": "Adding your ₱15 transport expense.",
  "actions": [
    { "type": "log_expense", "amount": 15, "category": "Transport" }
  ]
}
```''';
      final replyPrefixed =
          coach.parseEnvelopeForTesting(prefixedResponse, 'Paid 15 for jeep');
      coach.recordAssistantTurnForTesting(prefixedResponse, replyPrefixed);
      final stored =
          json.decode(coach.conversation.last.content) as Map<String, dynamic>;
      expect((stored['actions'] as List), hasLength(1));
    });

    test(
        'syncLastAssistantActions updates conversation when fallback parser recovers actions',
        () {
      const plainReply = 'Got it, logging ₱15 for your jeepney fare.';
      final reply =
          coach.parseEnvelopeForTesting(plainReply, 'Paid ₱15 jeep fare');
      coach.recordAssistantTurnForTesting(plainReply, reply);

      coach.syncLastAssistantActions(
        plainReply,
        const [
          LogTransactionAction(
            amount: 15,
            isIncome: false,
            category: 'Transport',
            note: 'jeep fare',
          ),
        ],
      );

      final stored =
          json.decode(coach.conversation.last.content) as Map<String, dynamic>;
      expect((stored['actions'] as List), hasLength(1));
      expect((stored['actions'] as List).first['type'], 'log_expense');
    });

    test(
        'RemoteCoach system prompt includes budgets and active subscriptions',
        () {
      final snap = FinanceSnapshot(
        walletBalances: {'BDO': 20000},
        totalDebt: 5000,
        monthIncome: 45000,
        monthExpense: 22000,
        monthExpenseByCategory: {'Food': 12000},
        budgets: {'Food': 10000},
        subscriptions: [
          SubscriptionSnapshot(
            name: 'Netflix',
            amount: 549,
            cadence: 'Monthly',
            category: 'Subscriptions',
            nextBillingDate: DateTime(2026, 11, 1),
          ),
        ],
        debts: const [],
        suggestions: const [],
      );

      final prompt = coach.systemPromptForTesting(snap);
      expect(prompt, contains('## Category Budgets'));
      expect(prompt, contains('Food: ₱10000.00/mo limit'));
      expect(prompt, contains('## Active Subscriptions'));
      expect(prompt, contains('Netflix: ₱549.00 (Monthly, Subscriptions)'));
      expect(prompt, contains('create_budget'));
    });

    test(
        'coachServiceProvider hydrates SQLite chat_messages with JSON actions and produces cards on follow-up turns without context reset',
        () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final db = AppDatabase.instance;
      db.overridePath = inMemoryDatabasePath;
      await db.close();

      final container = ProviderContainer();
      addTearDown(() async {
        container.dispose();
        await db.close();
      });

      // Persist Turn 1 in SQLite (plain text assistant message, as CoachScreen stores it)
      await container.read(chatListProvider.notifier).add(
            ChatMessage(
              id: 'u1',
              role: ChatRole.user,
              content: 'Paid ₱15 jeep fare',
              timestamp: DateTime(2026, 10, 17, 8, 0),
            ),
          );
      await container.read(chatListProvider.notifier).add(
            ChatMessage(
              id: 'a1',
              role: ChatRole.assistant,
              content: 'Prepared a card for ₱15 jeep fare.',
              timestamp: DateTime(2026, 10, 17, 8, 1),
            ),
          );

      await container.read(settingsProvider.notifier).update(
            const AppSettings(
              aiProvider: AIProvider.openrouter,
              allowRemoteAI: true,
            ),
          );

      final hydrated =
          await container.read(coachServiceProvider.future) as RemoteCoach;
      expect(hydrated.conversation, hasLength(2));
      final turn1Assistant =
          json.decode(hydrated.conversation.last.content) as Map<String, dynamic>;
      expect(turn1Assistant['reply'], 'Prepared a card for ₱15 jeep fare.');
      expect((turn1Assistant['actions'] as List), hasLength(1));
      expect((turn1Assistant['actions'] as List).first['type'], 'log_expense');
      expect((turn1Assistant['actions'] as List).first['amount'], 15);

      // Turn 2: User logs a second expense without resetting context
      const turn2User = 'Spent 150 lunch';
      hydrated.conversation.add((role: 'user', content: turn2User));
      const turn2PlainReply = 'Logged ₱150 for lunch.';
      final turn2Reply =
          hydrated.parseEnvelopeForTesting(turn2PlainReply, turn2User);
      hydrated.recordAssistantTurnForTesting(turn2PlainReply, turn2Reply);

      // Fallback parser recovers the card and syncs conversation
      final recovered =
          CoachActionParser().parse(assistantReply: '', userMessage: turn2User);
      expect(recovered, hasLength(1));
      hydrated.syncLastAssistantActions(turn2PlainReply, recovered);

      final turn2Assistant =
          json.decode(hydrated.conversation.last.content) as Map<String, dynamic>;
      expect((turn2Assistant['actions'] as List), hasLength(1));
      expect((turn2Assistant['actions'] as List).first['amount'], 150);
    });
  });
}
