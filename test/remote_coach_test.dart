import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_tracker/services/ai/ai_provider_config.dart';
import 'package:finance_tracker/services/ai/remote_coach.dart';
import 'package:finance_tracker/services/coach_actions.dart';

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
    });
  });
}
