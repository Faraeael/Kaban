import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../coach_actions.dart';
import 'ai_provider_config.dart';
import 'coach_service.dart';

/// Talks to any remote AI provider. Branches on `config.responseShape`:
/// - `openaiChat` (CommandCode, OpenRouter, OpenCode): /chat/completions with
///   Authorization: Bearer key.
/// - `gemini` (Google): /models/{model}:generateContent with `?key=` query.
class RemoteCoach implements CoachService {
  final AIProviderConfig config;
  final String apiKey;
  final String baseUrl;
  final String model;
  final bool anonymizeBalances;
  final bool useActionSchema;
  final List<({String role, String content})> conversation;

  RemoteCoach({
    required this.config,
    required this.apiKey,
    required this.baseUrl,
    required this.model,
    this.anonymizeBalances = true,
    this.useActionSchema = true,
    List<({String role, String content})>? history,
  }) : conversation = history ?? [];

  String _round(double v) {
    if (!anonymizeBalances) return '₱${v.toStringAsFixed(2)}';
    return '~₱${((v / 100).round() * 100).toStringAsFixed(0)}';
  }

  String _buildSystemPrompt(FinanceSnapshot snapshot) {
    final walletLines = snapshot.walletBalances.entries
        .map((e) => '  - ${e.key}: ${_round(e.value)}')
        .join('\n');
    final debtLines = snapshot.debts.isEmpty
        ? '  (none)'
        : snapshot.debts.map((d) {
            final schedInfo = switch (d.schedule) {
              'fixed' =>
                ', fixed schedule (due day ${d.dueDay ?? '?'}, ${d.remainingPayments ?? '?'} payments left)',
              'statementCycle' =>
                ', statement cycle (billing day ${d.billingDay ?? '?'}, grace ${d.graceDays ?? '?'} days)',
              _ => '',
            };
            return '  - ${d.name}: balance ${_round(d.balance)}, APR ${d.apr.toStringAsFixed(1)}%, min payment ${_round(d.minPayment)}/mo$schedInfo';
          }).join('\n');
    final catLines = snapshot.monthExpenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final catText = catLines.isEmpty
        ? '  (none)'
        : catLines.map((e) => '  - ${e.key}: ${_round(e.value)}').join('\n');

    if (!useActionSchema) {
      return '''You are a personal finance coach for a Filipino user. The data below has been anonymized — wallet names are general categories, no merchant names, no personal notes. ${anonymizeBalances ? 'All amounts are rounded to the nearest ₱100.' : 'Amounts are exact.'}

Use this data to answer questions and give practical advice. Keep responses concise (3-5 sentences).

## Wallets
$walletLines

## Month-to-date
  - Income: ${_round(snapshot.monthIncome)}
  - Expense: ${_round(snapshot.monthExpense)}

## Top expense categories this month
$catText

## Debts
$debtLines

## Total debt
  ${_round(snapshot.totalDebt)}
''';
    }

    return '''You are a personal finance coach for a Filipino user. The data below has been anonymized — wallet names are general categories, no merchant names, no personal notes. ${anonymizeBalances ? 'All amounts are rounded to the nearest ₱100.' : 'Amounts are exact.'}

Use this data to answer questions and give practical advice. Keep responses concise (3-5 sentences). Suggest concrete actions. Values marked with ~ are approximate context only and must never be copied into an action confirmation. Never round, alter, or invent an amount stated in the user's message. For example, if the user says "create a BDO wallet with 1983.67", acknowledge exactly ₱1,983.67; do not say ₱2,000. The user's exact amount always takes priority over any approximate snapshot value.

Respond with strict JSON in this exact shape:
{
  "reply": "natural-language answer for the user",
  "actions": [
    ...list of action objects
  ]
}

Action types and field schemas:
- create_wallet: { "type": "create_wallet", "name": string, "starting_balance": number }
- update_wallet: { "type": "update_wallet", "name": string, "new_name"?: string, "new_starting_balance"?: number, "unarchive"?: boolean }
- archive_wallet: { "type": "archive_wallet", "name": string }
- adjust_wallet_balance: { "type": "adjust_wallet_balance", "name": string, "target_balance": number }
- log_income: { "type": "log_income", "amount": number, "category": string, "note"?: string, "wallet_name"?: string }
- log_expense: { "type": "log_expense", "amount": number, "category": string, "note"?: string, "wallet_name"?: string }
- create_debt: { "type": "create_debt", "name": string, "balance": number, "apr": number, "min_payment": number, "schedule": "fixed"|"statementCycle"|"none", "due_day"?: number (1-31), "remaining_payments"?: number, "billing_day"?: number (1-31), "grace_days"?: number }
- pay_debt: { "type": "pay_debt", "name": string, "amount": number, "wallet_name"?: string }
- update_debt: { "type": "update_debt", "name": string, "new_name"?: string, "new_balance"?: number, "new_apr"?: number, "new_min_payment"?: number, "new_schedule"?: "fixed"|"statementCycle"|"none", "new_due_day"?: number, "new_remaining_payments"?: number, "new_billing_day"?: number, "new_grace_days"?: number }
- delete_debt: { "type": "delete_debt", "name": string }
- create_goal: { "type": "create_goal", "name": string, "target": number }
- add_to_goal: { "type": "add_to_goal", "name": string, "amount": number }
- update_goal: { "type": "update_goal", "name": string, "new_name"?: string, "new_target"?: number, "new_saved"?: number }
- delete_goal: { "type": "delete_goal", "name": string }
- create_recurring: { "type": "create_recurring", "name": string, "amount": number, "frequency": "daily"|"weekly"|"bi-weekly"|"monthly"|"yearly", "kind": "income"|"expense", "category": string }
- update_recurring: { "type": "update_recurring", "name": string, "new_amount"?: number, "new_frequency"?: string, "new_enabled"?: boolean, "delete"?: boolean }

Strict rules:
- YOUR CAPABILITIES & SKILLS: You are Kaban's AI Financial Coach with real in-app action card capabilities. When the user asks what you can do, what your skills are, or how to use the coach:
  1. Clearly state that you can actively manage their finances through interactive action cards: log expenses (commute fares, dining, shopping, bills) and income, create new wallets and adjust balances, set up and pay down debts, create savings goals, and track recurring expenses.
  2. Give examples of what they can say (e.g. "Paid ₱15 jeep fare", "Add a Maya wallet with 5000", "Paid 500 to my BDO card", "Create emergency fund goal of 50k").
  3. Invite them to try any of these directly!
- MULTI-TURN CONTINUITY & CARDS: Even if the conversation has multiple turns or is ongoing, whenever the user reports an expense, income, debt payment, wallet adjustment, or goal, you MUST ALWAYS generate the corresponding action card in the "actions" array. Never omit the action card just because previous messages also had cards or were conversational.
- CRITICAL: Action cards ONLY appear in the app if you return them in the "actions" array of THIS JSON response. The user must review and tap "Confirm" to apply them.
- CONSECUTIVE & REPEATED EXPENSES: Users frequently log expenses back-to-back (e.g. logging a ₱13 jeep fare, and then immediately logging a ₱15 jeep fare). EACH expense is a DISTINCT new transaction! You MUST ALWAYS emit a new log_expense action card in the "actions" array for every expense mentioned by the user, even if they just logged a similar one.
- NEVER say "I already sent it", "I already sent a card", "I queued them", "they are in the action panel", or "scroll up to review". If the user mentions an expense or requests an action, you MUST provide the card right now in "actions" of this response.
- If the user says "confirm", "send the card", "show the card", "accept", "it's not here", or repeats an unlogged item, you MUST include the complete action objects in your "actions" array so the interactive cards are presented right now.
- Filipino context:
  - Jeep / jeepney / tricycle / trike / bus / MRT / LRT / fare / commute / grab / angkas / joyride -> category: "Transport".
  - Jollibee / McDo / restaurant / cafe / lunch / dinner / food -> category: "Food".
  - If the user specifies a wallet (e.g. "put under Cash", "from GCash", "via Maya"), set wallet_name.
- All numbers for numeric fields (balance, min_payment, apr, amount, due_day, remaining_payments) MUST be output as raw JSON numbers (e.g. 50692.25, 15, 10), NEVER as formatted strings like "50,692.25", "15th", or "10mths".
- When the user describes a fixed installment loan (e.g. "Amount: 5494.16 ... 3 more times" or "5000/mo for 6 months"):
  - set min_payment = the stated installment amount (e.g. 5494.16).
  - calculate total balance = installment * count (e.g. 5494.16 * 3 = 16482.48). NEVER set balance to only a single installment when multiple payments are remaining.
  - set schedule = "fixed", remaining_payments = count, due_day = stated due day.
  - if APR is not specified, default to 0.0.
- When the user describes stepped or multi-tier loan payments (changing amounts over time, e.g. "5494 for 2 months, then 4513 for 6 months"):
  - calculate the grand total remaining balance across all installments.
  - propose create_debt with the grand total balance and the current monthly installment as min_payment, and explain in "reply" that they can update the monthly payment in the chat when the lower payment period begins.
- For debt payments or paying down a debt (e.g. "Paid 500 to BDO from Maya" or "Payment of 1000 toward Mariloan"):
  - use pay_debt with name, amount, and optional wallet_name. This subtracts from the debt balance and deducts from the paying wallet.
- UNTRACKED DEBTS & INITIAL BALANCES:
  - If a user reports paying a debt that does not exist in ## Debts, do NOT emit a standalone pay_debt. Offer create_debt to track the debt first.
  - When the user adds a new debt after mentioning a payment, the balance they enter is ALREADY their remaining balance. NEVER emit a pay_debt action deducting that same payment again from the newly added debt.
- RECEIPT & TRANSACTION SCREENSHOT SCANNING (GCash, Maya, Bank Slips, Invoices, Paper Receipts):
  - When the user sends a receipt or payment screenshot:
    - Sent money / Paid merchant / Bank transfer -> emit log_expense.
    - Received money / Cash-in / Refund -> emit log_income.
    - Transfer between own accounts (e.g. GCash to BPI) -> emit transfer.
    - Paying a tracked debt -> emit pay_debt.
  - Read the exact amount from the image (look for "Total", "Amount", "PHP", "₱", "Paid").
  - Identify merchant / recipient as note and choose an appropriate category (Food, Transport, Utilities, Shopping, Health, etc.).
  - Identify the source wallet from the screenshot (e.g. GCash, Maya, BPI, BDO, GoTyme, MariBank, SeaBank, etc.) and specify wallet_name.
  - Always return the proposed transaction in "actions" so the user can verify with an action card.
- To set, update, or correct a debt's balance, APR, monthly payment, due day, or schedule (e.g. "update Mariloan balance to 41453.36" or "change min payment to 4513.33"), use update_debt with new_balance and/or new_min_payment. NEVER use pay_debt to update balance.
- Never invent numbers out of thin air. Calculated balances (installment * count) are allowed and required for installment loans.
- If any required field is missing or ambiguous, return "actions": [] and explain in "reply".
- Prefer create_debt for debts with a schedule; only use create_recurring for ongoing habits.
- For balance adjustments or when user states current wallet balance (e.g. "My MariBank balance is 50,420.50" or "Adjust GoTyme to 15,000"), return adjust_wallet_balance. The app will calculate the delta.
- For interest credits or dividends (e.g. "Received 84.32 interest from GoTyme"), return log_income with category "Investment", note "Interest", and wallet_name.
- You CANNOT execute actions yourself; all proposed mutations MUST be returned in the "actions" array so the user can review and confirm them.

## Wallets
$walletLines

## Month-to-date
  - Income: ${_round(snapshot.monthIncome)}
  - Expense: ${_round(snapshot.monthExpense)}

## Top expense categories this month
$catText

## Debts
$debtLines

## Total debt
  ${_round(snapshot.totalDebt)}
''';
  }

  CoachReply _parseEnvelope(String rawText, String userMessage,
      {FinanceSnapshot? snapshot, bool hasImageAttachment = false}) {
    if (!useActionSchema) {
      return CoachReply(text: rawText, actions: const [], warnings: const []);
    }
    try {
      var jsonStr = rawText.trim();
      final mdMatch =
          RegExp(r'```(?:json)?\s*(\{[\s\S]*?\}|\[[\s\S]*?\])\s*```')
              .firstMatch(jsonStr);
      if (mdMatch != null) {
        jsonStr = mdMatch.group(1)!;
      } else {
        final startObj = jsonStr.indexOf('{');
        final endObj = jsonStr.lastIndexOf('}');
        final startArr = jsonStr.indexOf('[');
        final endArr = jsonStr.lastIndexOf(']');
        if (startObj >= 0 &&
            endObj > startObj &&
            (startArr < 0 || startObj < startArr)) {
          jsonStr = jsonStr.substring(startObj, endObj + 1);
        } else if (startArr >= 0 && endArr > startArr) {
          jsonStr = jsonStr.substring(startArr, endArr + 1);
        }
      }

      // Strip trailing commas before closing braces/brackets
      jsonStr = jsonStr.replaceAll(RegExp(r',\s*([\]}])'), r'$1');

      final decoded = json.decode(jsonStr);
      final parsedActions = <CoachAction>[];
      String replyText = rawText;

      if (decoded is List) {
        for (final a in decoded) {
          if (a is Map) {
            final parsed = parseJsonAction(Map<String, dynamic>.from(a));
            if (parsed != null) parsedActions.add(parsed);
          }
        }
      } else if (decoded is Map<String, dynamic>) {
        replyText = (decoded['reply'] ??
                    decoded['message'] ??
                    decoded['text'] as String?)
                ?.trim() ??
            rawText;
        final rawActions = (decoded['actions'] ??
            decoded['action_list'] ??
            decoded['operations']) as List?;
        if (rawActions != null) {
          for (final a in rawActions) {
            if (a is Map) {
              final parsed = parseJsonAction(Map<String, dynamic>.from(a));
              if (parsed != null) parsedActions.add(parsed);
            }
          }
        } else if (decoded['type'] != null || decoded['action'] != null) {
          final single = parseJsonAction(decoded);
          if (single != null) parsedActions.add(single);
        }
      }

      if (parsedActions.isNotEmpty) {
        final recentUserTurns = conversation
            .where((m) => m.role == 'user' && m.content != userMessage)
            .map((m) => m.content)
            .toList()
            .reversed
            .take(5)
            .toList();
        final recentAssistantTurns = conversation
            .where((m) => m.role == 'assistant' || m.role == 'model')
            .map((m) => m.content)
            .toList()
            .reversed
            .take(5)
            .toList();
        final knownNames = [
          if (snapshot != null) ...snapshot.walletBalances.keys,
          if (snapshot != null) ...snapshot.debts.map((d) => d.name),
        ];
        final validated = validateAgainstUserMessage(
          actions: parsedActions,
          userMessage: userMessage,
          recentUserMessages: recentUserTurns,
          recentAssistantMessages: recentAssistantTurns,
          knownEntityNames: knownNames,
          hasImageAttachment: hasImageAttachment,
        );
        return CoachReply(
          text: replyText,
          actions: validated.actions,
          warnings: validated.warnings,
        );
      } else if (decoded is Map<String, dynamic> && decoded['reply'] != null) {
        return CoachReply(
          text: replyText,
          actions: const [],
          warnings: const [],
        );
      }
    } catch (_) {
      // Fall through to plain reply
    }

    return CoachReply(text: rawText, actions: const [], warnings: const []);
  }

  void _recordAssistantTurn(String rawContent, CoachReply reply) {
    if (useActionSchema) {
      final trimmed = rawContent.trim();
      final storedContent =
          (trimmed.startsWith('{') || trimmed.startsWith('```'))
              ? trimmed
              : json.encode({'reply': reply.text, 'actions': const []});
      conversation.add((role: 'assistant', content: storedContent));
    } else {
      conversation.add((role: 'assistant', content: reply.text));
    }
  }

  @visibleForTesting
  void recordAssistantTurnForTesting(String rawContent, CoachReply reply) =>
      _recordAssistantTurn(rawContent, reply);

  @visibleForTesting
  CoachReply parseEnvelopeForTesting(String rawText, String userMessage,
          {FinanceSnapshot? snapshot}) =>
      _parseEnvelope(rawText, userMessage, snapshot: snapshot);

  @override
  Future<CoachReply> ask(String userMessage, FinanceSnapshot snapshot,
      {Uint8List? imageBytes, String? imageMimeType}) async {
    if (config.responseShape == ResponseShape.gemini) {
      return _askGemini(userMessage, snapshot,
          imageBytes: imageBytes, imageMimeType: imageMimeType);
    }
    return _askOpenAI(userMessage, snapshot,
        imageBytes: imageBytes, imageMimeType: imageMimeType);
  }

  Future<CoachReply> _askOpenAI(String userMessage, FinanceSnapshot snapshot,
      {Uint8List? imageBytes, String? imageMimeType}) async {
    // Guard against double-appending when the conversation was hydrated
    // from the DB after the user's message was already persisted.
    if (conversation.isEmpty ||
        conversation.last.role != 'user' ||
        conversation.last.content != userMessage) {
      conversation.add((role: 'user', content: userMessage));
    }

    final recentConversation = conversation.length > 20
        ? conversation.sublist(conversation.length - 20)
        : conversation;

    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': _buildSystemPrompt(snapshot)},
    ];

    for (var i = 0; i < recentConversation.length; i++) {
      final m = recentConversation[i];
      final isLast = (i == recentConversation.length - 1 && m.role == 'user');
      if (isLast && imageBytes != null) {
        messages.add({
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text': m.content.isEmpty
                  ? 'Please scan this receipt or transaction screenshot and log it.'
                  : m.content,
            },
            {
              'type': 'image_url',
              'image_url': {
                'url':
                    'data:${imageMimeType ?? "image/jpeg"};base64,${base64Encode(imageBytes)}',
              },
            },
          ],
        });
      } else {
        messages.add({'role': m.role, 'content': m.content});
      }
    }

    final body = {
      'model': model,
      'messages': messages,
      'temperature': 0.2,
      'max_tokens': 2048,
    };

    final uri = Uri.parse('$baseUrl/chat/completions');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
      },
      body: json.encode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(
          'AI provider returned ${response.statusCode}: ${response.body}');
    }

    final decoded = json.decode(response.body);
    final content = decoded['choices']?[0]?['message']?['content'] as String?;
    if (content == null) {
      throw Exception('AI provider response missing content');
    }

    final reply = _parseEnvelope(content, userMessage,
        snapshot: snapshot, hasImageAttachment: imageBytes != null);
    _recordAssistantTurn(content, reply);
    return reply;
  }

  Future<CoachReply> _askGemini(String userMessage, FinanceSnapshot snapshot,
      {Uint8List? imageBytes, String? imageMimeType}) async {
    // Gemini uses query-param auth, model in path, and {contents: [...]} body.
    if (apiKey.isEmpty) {
      throw Exception(
          'Google API key is empty. Paste one in Settings → AI Coach.');
    }

    if (conversation.isEmpty ||
        conversation.last.role != 'user' ||
        conversation.last.content != userMessage) {
      conversation.add((role: 'user', content: userMessage));
    }

    final systemPrompt = _buildSystemPrompt(snapshot);
    final recentConversation = conversation.length > 20
        ? conversation.sublist(conversation.length - 20)
        : conversation;

    // Build clean alternating contents for Gemini (strictly alternating user / model)
    final cleanContents = <Map<String, dynamic>>[];
    for (final m in recentConversation) {
      final role =
          (m.role == 'assistant' || m.role == 'model') ? 'model' : 'user';
      if (cleanContents.isNotEmpty && cleanContents.last['role'] == role) {
        final lastPart =
            (cleanContents.last['parts'] as List).first as Map<String, dynamic>;
        lastPart['text'] = '${lastPart['text']}\n\n${m.content}';
      } else {
        cleanContents.add({
          'role': role,
          'parts': [
            {'text': m.content}
          ],
        });
      }
    }
    // Ensure the conversation starts with a user turn
    if (cleanContents.isNotEmpty && cleanContents.first['role'] != 'user') {
      cleanContents.removeAt(0);
    }
    // Ensure the conversation ends with the current user turn
    if (cleanContents.isEmpty || cleanContents.last['role'] != 'user') {
      cleanContents.add({
        'role': 'user',
        'parts': [
          {'text': userMessage}
        ],
      });
    }

    // Attach image to the final user turn if present
    if (imageBytes != null && cleanContents.isNotEmpty) {
      final lastTurn = cleanContents.last;
      if (lastTurn['role'] == 'user') {
        final promptText = userMessage.isEmpty
            ? 'Please scan this receipt or transaction screenshot and log it.'
            : userMessage;
        lastTurn['parts'] = [
          {'text': promptText},
          {
            'inline_data': {
              'mime_type': imageMimeType ?? 'image/jpeg',
              'data': base64Encode(imageBytes),
            },
          },
        ];
      }
    }

    final body = {
      'system_instruction': {
        'parts': [
          {'text': systemPrompt}
        ],
      },
      'contents': cleanContents,
      'generationConfig': {
        'temperature': 0.2,
        // Gemini 2.5+ "thinking" models burn output tokens on reasoning and
        // can return MAX_TOKENS with little or no visible text. Disable
        // thinking unless the model requires it.
        if (!model.toLowerCase().contains('thinking'))
          'thinkingConfig': {
            'thinkingBudget': 0,
          },
        'maxOutputTokens': 2048,
        if (useActionSchema) 'responseMimeType': 'application/json',
      },
    };

    final uri = Uri.parse(
        '$baseUrl/models/${Uri.encodeComponent(model)}:generateContent?key=$apiKey');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(
          'AI provider returned ${response.statusCode}: ${response.body}');
    }

    final decoded = json.decode(response.body);
    final content = _extractGeminiText(decoded);
    if (content == null || content.isEmpty) {
      throw Exception(
          'Gemini returned an empty reply (200 OK). If the model is a '
          '"thinking" model, it may have used up its response budget on '
          'reasoning. Try a non-thinking model such as '
          '${kAIProviders[AIProvider.google]!.defaultModel}.');
    }

    final reply = _parseEnvelope(content, userMessage,
        snapshot: snapshot, hasImageAttachment: imageBytes != null);
    _recordAssistantTurn(content, reply);
    return reply;
  }

  /// Gemini returns text under
  /// `candidates[0].content.parts[*].text`. We concatenate all parts in
  /// case the response spans multiple parts.
  static String? _extractGeminiText(dynamic decoded) {
    try {
      final candidates = decoded['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return null;
      final first = candidates.first as Map<String, dynamic>;
      final content = first['content'] as Map<String, dynamic>?;
      if (content == null) return null;
      final parts = content['parts'] as List?;
      if (parts == null || parts.isEmpty) return null;
      final texts = <String>[];
      for (final p in parts) {
        final t = (p as Map<String, dynamic>)['text'] as String?;
        if (t != null) texts.add(t);
      }
      return texts.isEmpty ? null : texts.join();
    } catch (_) {
      return null;
    }
  }

  @override
  List<String> suggestedPrompts(FinanceSnapshot snapshot) {
    final prompts = <String>[];
    prompts.add('Paid ₱15 jeep fare');
    if (snapshot.debts.isNotEmpty) {
      prompts.add('What\'s the smartest order to pay my debts?');
    }
    if (snapshot.monthExpenseByCategory.isNotEmpty) {
      prompts.add('Where can I cut back this month?');
    }
    prompts.add('Give me a one-month financial plan.');
    if (snapshot.walletBalances.isNotEmpty) {
      prompts.add('Am I spread too thin across my wallets?');
    }
    return prompts.take(5).toList();
  }
}
