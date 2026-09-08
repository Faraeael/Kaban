import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../data/budget_repository.dart';
import '../data/chat_repository.dart';
import '../data/database.dart';
import '../data/debt_repository.dart';
import '../data/goal_repository.dart';
import '../data/notification_event_repository.dart';
import '../data/recurring_repository.dart';
import '../data/subscription_repository.dart';
import '../data/transaction_repository.dart';
import '../data/wallet_repository.dart';
import '../models/budget.dart';
import '../models/chat_message.dart';
import '../models/debt.dart';
import '../models/goal.dart';
import '../models/notification_event.dart';
import '../models/recurring_transaction.dart';
import '../models/subscription.dart';
import '../models/transaction.dart';
import '../models/wallet.dart';
import '../services/ai/ai_provider_config.dart';
import '../services/ai/coach_service.dart';
import '../services/ai/local_coach.dart';
import '../services/ai/remote_coach.dart';
import '../services/backup_service.dart';
import '../services/balance_recalculator.dart';
import '../services/notification_listener.dart';
import '../services/notification_parser.dart';
import '../services/payoff_calculator.dart';
import '../services/recurring_engine.dart';
import '../services/spending_analyzer.dart';
import '../services/subscription_detector.dart';
import 'settings_provider.dart';

const _uuid = Uuid();

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase.instance);

final walletRepoProvider = Provider<WalletRepository>(
    (ref) => WalletRepository(ref.watch(databaseProvider)));
final transactionRepoProvider = Provider<TransactionRepository>(
    (ref) => TransactionRepository(ref.watch(databaseProvider)));
final debtRepoProvider = Provider<DebtRepository>(
    (ref) => DebtRepository(ref.watch(databaseProvider)));
final goalRepoProvider = Provider<GoalRepository>(
    (ref) => GoalRepository(ref.watch(databaseProvider)));
final budgetRepoProvider = Provider<BudgetRepository>(
    (ref) => BudgetRepository(ref.watch(databaseProvider)));
final subscriptionRepoProvider = Provider<SubscriptionRepository>(
    (ref) => SubscriptionRepository(ref.watch(databaseProvider)));
final notifEventRepoProvider = Provider<NotificationEventRepository>(
    (ref) => NotificationEventRepository(ref.watch(databaseProvider)));
final chatRepoProvider = Provider<ChatRepository>(
    (ref) => ChatRepository(ref.watch(databaseProvider)));
final backupServiceProvider = Provider<BackupService>(
    (ref) => BackupService(ref.watch(databaseProvider)));
final recurringRepoProvider = Provider<RecurringRepository>(
    (ref) => RecurringRepository(ref.watch(databaseProvider)));
final recurringEngineProvider = Provider<RecurringEngine>(
    (ref) => RecurringEngine(ref.watch(databaseProvider)));

final walletListProvider =
    StateNotifierProvider<WalletListNotifier, List<Wallet>>((ref) {
  return WalletListNotifier(ref.watch(walletRepoProvider));
});

class WalletListNotifier extends StateNotifier<List<Wallet>> {
  final WalletRepository _repo;
  WalletListNotifier(this._repo) : super(const []);

  Future<void> load() async {
    state = await _repo.listAll();
  }

  Future<void> add(Wallet w) async {
    await _repo.insert(w);
    await load();
  }

  Future<void> update(Wallet w) async {
    await _repo.update(w);
    await load();
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    await load();
  }
}

final transactionListProvider =
    StateNotifierProvider<TransactionListNotifier, List<Transaction>>((ref) {
  return TransactionListNotifier(ref.watch(transactionRepoProvider));
});

class TransactionListNotifier extends StateNotifier<List<Transaction>> {
  final TransactionRepository _repo;
  TransactionListNotifier(this._repo) : super(const []);

  Future<void> load() async {
    state = await _repo.listAll();
  }

  Future<void> add(Transaction t) async {
    await _repo.insert(t);
    await load();
  }

  Future<void> addMany(List<Transaction> ts) async {
    await _repo.insertMany(ts);
    await load();
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    await load();
  }

  Future<void> deleteTransferPair(String pairId) async {
    await _repo.deleteByTransferPair(pairId);
    await load();
  }
}

final debtListProvider =
    StateNotifierProvider<DebtListNotifier, List<Debt>>((ref) {
  return DebtListNotifier(ref.watch(debtRepoProvider));
});

class DebtListNotifier extends StateNotifier<List<Debt>> {
  final DebtRepository _repo;
  DebtListNotifier(this._repo) : super(const []);

  Future<void> load() async {
    state = await _repo.listAll();
  }

  Future<void> add(Debt d) async {
    await _repo.insert(d);
    await load();
  }

  Future<void> update(Debt d) async {
    await _repo.update(d);
    await load();
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    await load();
  }
}

final goalListProvider =
    StateNotifierProvider<GoalListNotifier, List<Goal>>((ref) {
  return GoalListNotifier(ref.watch(goalRepoProvider));
});

class GoalListNotifier extends StateNotifier<List<Goal>> {
  final GoalRepository _repo;
  GoalListNotifier(this._repo) : super(const []);

  Future<void> load() async {
    state = await _repo.listAll();
  }

  Future<void> add(Goal g) async {
    await _repo.insert(g);
    await load();
  }

  Future<void> update(Goal g) async {
    await _repo.update(g);
    await load();
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    await load();
  }
}

final budgetListProvider =
    StateNotifierProvider<BudgetListNotifier, List<Budget>>((ref) {
  return BudgetListNotifier(ref.watch(budgetRepoProvider));
});

class BudgetListNotifier extends StateNotifier<List<Budget>> {
  final BudgetRepository _repo;
  BudgetListNotifier(this._repo) : super(const []);

  Future<void> load() async {
    state = await _repo.listAll();
  }

  Future<void> upsert(Budget b) async {
    await _repo.upsert(b);
    await load();
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    await load();
  }
}

final subscriptionListProvider =
    StateNotifierProvider<SubscriptionListNotifier, List<Subscription>>((ref) {
  return SubscriptionListNotifier(ref.watch(subscriptionRepoProvider));
});

class SubscriptionListNotifier extends StateNotifier<List<Subscription>> {
  final SubscriptionRepository _repo;
  SubscriptionListNotifier(this._repo) : super(const []);

  Future<void> load() async {
    state = await _repo.listAll();
  }

  Future<void> add(Subscription s) async {
    await _repo.insert(s);
    await load();
  }

  Future<void> update(Subscription s) async {
    await _repo.update(s);
    await load();
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    await load();
  }
}

final chatListProvider =
    StateNotifierProvider<ChatListNotifier, List<ChatMessage>>((ref) {
  return ChatListNotifier(ref.watch(chatRepoProvider));
});

class ChatListNotifier extends StateNotifier<List<ChatMessage>> {
  final ChatRepository _repo;
  ChatListNotifier(this._repo) : super(const []);

  Future<void> load() async {
    state = await _repo.listAll();
  }

  Future<void> add(ChatMessage m) async {
    await _repo.insert(m);
    await load();
  }

  Future<void> clear() async {
    await _repo.clear();
    state = const [];
  }
}

final notificationEventListProvider = StateNotifierProvider<
    NotificationEventListNotifier, List<NotificationEvent>>((ref) {
  return NotificationEventListNotifier(ref.watch(notifEventRepoProvider));
});

class NotificationEventListNotifier
    extends StateNotifier<List<NotificationEvent>> {
  final NotificationEventRepository _repo;
  NotificationEventListNotifier(this._repo) : super(const []);

  Future<void> load() async {
    state = await _repo.listRecent();
  }

  Future<void> add(NotificationEvent e) async {
    await _repo.insert(e);
    await load();
  }

  Future<void> clearAll() async {
    await _repo.deleteAll();
    state = const [];
  }
}

final recurringListProvider =
    StateNotifierProvider<RecurringListNotifier, List<RecurringTransaction>>(
        (ref) {
  return RecurringListNotifier(ref.watch(recurringRepoProvider));
});

class RecurringListNotifier extends StateNotifier<List<RecurringTransaction>> {
  final RecurringRepository _repo;
  RecurringListNotifier(this._repo) : super(const []);

  Future<void> load() async {
    state = await _repo.listAll();
  }

  Future<void> add(RecurringTransaction r) async {
    await _repo.insert(r);
    await load();
  }

  Future<void> update(RecurringTransaction r) async {
    await _repo.update(r);
    await load();
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    await load();
  }
}

final balanceRecalculatorProvider =
    Provider<BalanceRecalculator>((ref) => BalanceRecalculator());
final payoffCalculatorProvider =
    Provider<PayoffCalculator>((ref) => PayoffCalculator());
final spendingAnalyzerProvider =
    Provider<SpendingAnalyzer>((ref) => SpendingAnalyzer());
final subscriptionDetectorProvider =
    Provider<SubscriptionDetector>((ref) => SubscriptionDetector());
final notificationParserProvider =
    Provider<NotificationParser>((ref) => NotificationParser());
final notificationListenerProvider = Provider<NotificationListenerService>(
    (ref) => NotificationListenerService());
final notificationListenerServiceProvider = notificationListenerProvider;

final walletBalancesProvider = Provider<Map<String, double>>((ref) {
  final wallets = ref.watch(walletListProvider);
  final txns = ref.watch(transactionListProvider);
  final calc = ref.watch(balanceRecalculatorProvider);
  final balances = <String, double>{};
  for (final w in wallets) {
    if (w.archived) continue;
    final walletTxns = txns.where((t) => t.walletId == w.id).toList();
    balances[w.id] = calc.compute(w, walletTxns);
  }
  return balances;
});

final totalDebtProvider = Provider<double>((ref) {
  final debts = ref.watch(debtListProvider);
  return debts.fold(0, (s, d) => s + d.balance);
});

final netWorthProvider = Provider<double>((ref) {
  final balances = ref.watch(walletBalancesProvider).values;
  final debt = ref.watch(totalDebtProvider);
  return balances.fold<double>(0, (s, b) => s + b) - debt;
});

final monthSummaryProvider =
    Provider<({double income, double expense, Map<String, double> byCategory})>(
        (ref) {
  final txns = ref.watch(transactionListProvider);
  final month = DateTime.now();
  final start = DateTime(month.year, month.month, 1);
  final filtered = txns.where(
      (t) => !t.date.isBefore(start) && t.type != TransactionType.transfer);
  double income = 0, expense = 0;
  final byCat = <String, double>{};
  for (final t in filtered) {
    if (t.type == TransactionType.income) {
      income += t.amount;
    } else if (t.type == TransactionType.expense) {
      expense += t.amount;
      byCat[t.category] = (byCat[t.category] ?? 0) + t.amount;
    }
  }
  return (income: income, expense: expense, byCategory: byCat);
});

const _coachHistoryLimit = 20;

final coachServiceProvider = FutureProvider<CoachService>((ref) async {
  final settings = ref.watch(settingsProvider);
  if (!settings.allowRemoteAI || settings.aiProvider == AIProvider.local) {
    return LocalCoach();
  }
  final config = kAIProviders[settings.aiProvider]!;
  final baseUrl = settings.aiBaseUrl.isNotEmpty
      ? settings.aiBaseUrl
      : (config.defaultBaseUrl ?? '');
  final model = settings.aiModel.isNotEmpty
      ? settings.aiModel
      : (config.defaultModel ?? 'default');

  // Hydrate the AI's working memory from persisted chat so it remembers
  // across restarts. Capped to the last N messages to bound token cost.
  final history = await ref.read(chatRepoProvider).listAll();
  final recent = history.length > _coachHistoryLimit
      ? history.sublist(history.length - _coachHistoryLimit)
      : history;
  final conversation = recent.map((m) {
    return (role: m.role.name, content: m.content);
  }).toList();

  return RemoteCoach(
    config: config,
    apiKey: settings.aiApiKey,
    baseUrl: baseUrl,
    model: model,
    anonymizeBalances: settings.anonymizeBalances,
    history: conversation,
  );
});

String newId() => _uuid.v4();
