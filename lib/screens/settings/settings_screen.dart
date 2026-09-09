import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:local_auth/local_auth.dart';
import '../../models/debt.dart';
import '../../services/ai/ai_provider_config.dart';
import '../../services/backup_service.dart';
import '../../services/recurring_worker.dart';
import '../../state/data_providers.dart';
import '../../state/settings_provider.dart';
import '../onboarding/widgets/test_api_button.dart';
import 'widgets/model_picker.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _apiKey;
  late TextEditingController _baseUrl;
  late TextEditingController _model;

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    _apiKey = TextEditingController(text: s.aiApiKey);
    _baseUrl = TextEditingController(text: s.aiBaseUrl);
    _model = TextEditingController(text: s.aiModel);
  }

  @override
  void dispose() {
    _apiKey.dispose();
    _baseUrl.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        children: [
          _section('AI Coach', t),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Provider'),
            subtitle: Text(settings.aiProvider == AIProvider.local
                ? 'Local (offline rules)'
                : kAIProviders[settings.aiProvider]!.displayName),
          ),
          DropdownButtonFormField<AIProvider>(
            initialValue: settings.aiProvider,
            decoration: const InputDecoration(),
            items: AIProvider.values
                .map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(kAIProviders[p]!.displayName),
                    ))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              final config = kAIProviders[v]!;
              notifier.update(settings.copyWith(
                aiProvider: v,
                aiBaseUrl: config.defaultBaseUrl ?? settings.aiBaseUrl,
                aiModel: config.defaultModel ?? settings.aiModel,
                // Picking a remote provider means the user wants remote AI —
                // silently keeping it off is why the coach ignored the switch.
                allowRemoteAI: v != AIProvider.local,
              ));
            },
          ),
          const SizedBox(height: 10),
          if (settings.aiProvider != AIProvider.local) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow remote AI'),
              subtitle: const Text(
                  'Sends an anonymized snapshot to the configured endpoint'),
              value: settings.allowRemoteAI,
              onChanged: (v) =>
                  notifier.update(settings.copyWith(allowRemoteAI: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Anonymize balances'),
              subtitle:
                  const Text('Round amounts to nearest ₱100 before sending'),
              value: settings.anonymizeBalances,
              onChanged: (v) =>
                  notifier.update(settings.copyWith(anonymizeBalances: v)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _apiKey,
              decoration: const InputDecoration(labelText: 'API key'),
              obscureText: true,
              onChanged: (v) => notifier.update(settings.copyWith(aiApiKey: v)),
            ),
            const SizedBox(height: 10),
            _ModelField(
              currentModelId: settings.aiModel.isNotEmpty
                  ? settings.aiModel
                  : (kAIProviders[settings.aiProvider]!.defaultModel ?? ''),
              provider: settings.aiProvider,
              apiKey: settings.aiApiKey,
              baseUrl: settings.aiBaseUrl,
              onPick: (id) {
                _model.text = id;
                notifier.update(settings.copyWith(aiModel: id));
              },
              t: t,
            ),
            const SizedBox(height: 6),
            Theme(
              data: t.copyWith(
                dividerColor: Colors.transparent,
                expansionTileTheme: ExpansionTileThemeData(
                  childrenPadding: const EdgeInsets.only(top: 8),
                  tilePadding: EdgeInsets.zero,
                  iconColor: t.colorScheme.onSurfaceVariant,
                  textColor: t.colorScheme.onSurfaceVariant,
                ),
              ),
              child: Builder(builder: (context) {
                final cfg = kAIProviders[settings.aiProvider]!;
                final isDefault = settings.aiBaseUrl.isEmpty ||
                    settings.aiBaseUrl == cfg.defaultBaseUrl;
                return ExpansionTile(
                  title: Text(
                    'Advanced',
                    style: t.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  children: [
                    if (!isDefault)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Base URL is set to a non-default endpoint.',
                          style: t.textTheme.bodySmall?.copyWith(
                            color: t.colorScheme.error,
                          ),
                        ),
                      ),
                    TextField(
                      controller: _baseUrl,
                      decoration: const InputDecoration(
                        labelText: 'Base URL',
                        hintText:
                            'Only change if your provider gave you a custom endpoint',
                      ),
                      onChanged: (v) =>
                          notifier.update(settings.copyWith(aiBaseUrl: v)),
                    ),
                  ],
                );
              }),
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: t.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                kAIProviders[settings.aiProvider]!.docsHint,
                style: t.textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 12),
            TestApiButton(
              provider: settings.aiProvider,
              baseUrl: settings.aiBaseUrl.isNotEmpty
                  ? settings.aiBaseUrl
                  : (kAIProviders[settings.aiProvider]!.defaultBaseUrl ?? ''),
              apiKey: settings.aiApiKey,
              model: _model.text.isNotEmpty
                  ? _model.text
                  : (kAIProviders[settings.aiProvider]!.defaultModel ?? ''),
            ),
          ],
          const SizedBox(height: 20),
          _section('Auto-capture', t),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enable notification capture (Android)'),
            subtitle: const Text(
                'Read GCash, Maya, and bank notifications to log transactions automatically.'),
            value: settings.autoCaptureEnabled,
            onChanged: (v) async {
              notifier.update(settings.copyWith(autoCaptureEnabled: v));
              if (v) {
                final granted = await ref
                    .read(notificationListenerServiceProvider)
                    .isPermissionGranted();
                if (!granted) {
                  await ref
                      .read(notificationListenerServiceProvider)
                      .requestPermission();
                }
                await ref
                    .read(notificationListenerServiceProvider)
                    .syncWhitelist(settings.autoCapturePackages);
              }
            },
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            icon: const Icon(Icons.security_rounded, size: 18),
            label: const Text('Check / grant notification access in Android'),
            onPressed: () => ref
                .read(notificationListenerServiceProvider)
                .requestPermission(),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:
                  t.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Android 13+ note: For sideloaded apps, Android disables notification access by default. '
              'If the toggle is greyed out in Android Settings, go to App Info → ⋮ (top right) → "Allow restricted settings" first.',
              style: t.textTheme.bodySmall
                  ?.copyWith(color: t.colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Whitelisted packages',
            style: t.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          for (final pkg in settings.autoCapturePackages)
            Card(
              child: ListTile(
                title: Text(pkg, style: const TextStyle(fontSize: 13)),
                trailing: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Remove $pkg from whitelist',
                  onPressed: () {
                    final next = settings.autoCapturePackages.difference({pkg});
                    notifier
                        .update(settings.copyWith(autoCapturePackages: next));
                    ref
                        .read(notificationListenerServiceProvider)
                        .syncWhitelist(next);
                  },
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: () async {
              final c = TextEditingController();
              await showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Add package'),
                  content: TextField(
                      controller: c,
                      decoration:
                          const InputDecoration(hintText: 'com.example.app')),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel')),
                    FilledButton(
                      onPressed: () {
                        if (c.text.trim().isNotEmpty) {
                          final next = settings.autoCapturePackages
                              .union({c.text.trim()});
                          notifier.update(
                              settings.copyWith(autoCapturePackages: next));
                          ref
                              .read(notificationListenerServiceProvider)
                              .syncWhitelist(next);
                        }
                        Navigator.pop(ctx);
                      },
                      child: const Text('Add Package'),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add package'),
          ),
          const SizedBox(height: 20),
          _section('Defaults', t),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Default payoff strategy'),
            subtitle: Text(settings.defaultStrategy.label),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              final next = await showDialog<DebtStrategy>(
                context: context,
                builder: (ctx) => SimpleDialog(
                  title: const Text('Default strategy'),
                  children: DebtStrategy.values
                      .map((s) => SimpleDialogOption(
                            onPressed: () => Navigator.pop(ctx, s),
                            child: Text(s.label),
                          ))
                      .toList(),
                ),
              );
              if (next != null) {
                notifier.update(settings.copyWith(defaultStrategy: next));
              }
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Theme'),
            subtitle: Text(settings.themeMode.name),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              final next = await showDialog<ThemeMode>(
                context: context,
                builder: (ctx) => SimpleDialog(
                  title: const Text('Theme'),
                  children: ThemeMode.values
                      .map((m) => SimpleDialogOption(
                            onPressed: () => Navigator.pop(ctx, m),
                            child: Text(m.name),
                          ))
                      .toList(),
                ),
              );
              if (next != null) {
                notifier.update(settings.copyWith(themeMode: next));
              }
            },
          ),
          const SizedBox(height: 20),
          _section('Help', t),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.menu_book_rounded),
            title: const Text('How to use this app'),
            subtitle: const Text('Walks through every screen and feature'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/help'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.replay_rounded),
            title: const Text('Show onboarding again'),
            subtitle: const Text('Re-run the first-time setup wizard'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              await ref.read(settingsProvider.notifier).update(
                    ref
                        .read(settingsProvider)
                        .copyWith(onboardingComplete: false),
                  );
              if (context.mounted) context.go('/onboarding');
            },
          ),
          const SizedBox(height: 8),
          _section('Recurring', t),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto-log recurring'),
            subtitle: const Text(
                'Automatically log due recurring transactions (commute, meals, '
                'subscriptions) when the app opens.'),
            value: settings.autoRecurring,
            onChanged: (v) async {
              notifier.update(settings.copyWith(autoRecurring: v));
              try {
                await RecurringWorker.sync();
              } catch (_) {}
            },
          ),
          const SizedBox(height: 8),
          _section('Security', t),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Privacy Mode (Jeep Mode)'),
            subtitle: const Text(
                'Mask wallet balances and net worth across the app when in public or commuting.'),
            value: settings.privacyMode,
            onChanged: (v) =>
                notifier.update(settings.copyWith(privacyMode: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Biometric app lock'),
            subtitle:
                const Text('Require fingerprint, face, or device PIN when '
                    'opening the app or returning to it.'),
            value: settings.biometricLock,
            onChanged: (v) async {
              if (v) {
                final auth = LocalAuthentication();
                final canCheck = await auth.canCheckBiometrics ||
                    await auth.isDeviceSupported();
                if (!canCheck) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'No biometrics or screen lock set up on this '
                              'device. Set one in Android Settings first.')),
                    );
                  }
                  return;
                }
              }
              notifier.update(settings.copyWith(biometricLock: v));
            },
          ),
          const SizedBox(height: 8),
          _section('Data', t),
          SwitchListTile(
            title: const Text('Auto-backup on launch'),
            subtitle: const Text(
                'Silently saves a backup snapshot to your device each time you open the app.'),
            value: settings.autoBackupOnLaunch,
            onChanged: (v) => ref
                .read(settingsProvider.notifier)
                .update(settings.copyWith(autoBackupOnLaunch: v)),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Save backup'),
                  onPressed: () => _exportBackup(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('Share backup'),
                  onPressed: () => _shareBackup(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.restore_rounded),
            label: const Text('Import backup'),
            onPressed: () => _importBackup(context),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Clear all data'),
            style: OutlinedButton.styleFrom(
              foregroundColor: t.colorScheme.error,
              side:
                  BorderSide(color: t.colorScheme.error.withValues(alpha: 0.4)),
            ),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (dialogCtx) => AlertDialog(
                  title: const Text('Clear all data?'),
                  content: const Text(
                      'This deletes every wallet, transaction, debt, and goal. Cannot be undone.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogCtx, false),
                        child: const Text('Cancel')),
                    FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: t.colorScheme.error),
                      onPressed: () => Navigator.pop(dialogCtx, true),
                      child: const Text('Clear All Data'),
                    ),
                  ],
                ),
              );
              if (ok ?? false) {
                final db = ref.read(databaseProvider);
                final database = await db.db;
                await database.delete('transactions');
                await database.delete('wallets');
                await database.delete('debts');
                await database.delete('goals');
                await database.delete('budgets');
                await database.delete('subscriptions');
                await database.delete('recurring_transactions');
                await database.delete('notification_events');
                await database.delete('chat_messages');
                await Future.wait([
                  ref.read(walletListProvider.notifier).load(),
                  ref.read(transactionListProvider.notifier).load(),
                  ref.read(debtListProvider.notifier).load(),
                  ref.read(goalListProvider.notifier).load(),
                  ref.read(budgetListProvider.notifier).load(),
                  ref.read(subscriptionListProvider.notifier).load(),
                  ref.read(recurringListProvider.notifier).load(),
                  ref.read(notificationEventListProvider.notifier).load(),
                  ref.read(chatListProvider.notifier).load(),
                ]);
              }
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Kaban — your data stays on this device.',
            textAlign: TextAlign.center,
            style: t.textTheme.bodySmall
                ?.copyWith(color: t.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Future<void> _exportBackup(BuildContext context) async {
    try {
      final bytes = await ref.read(backupServiceProvider).export();
      final saved = await FilePicker.saveFile(
        fileName: BackupService.backupFileName(),
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: bytes,
      );
      if (saved != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup saved.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _shareBackup(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin =
        box != null ? box.localToGlobal(Offset.zero) & box.size : null;
    try {
      final bytes = await ref.read(backupServiceProvider).export();
      final name = BackupService.backupFileName();
      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            name: name,
            mimeType: 'application/json',
          ),
        ],
        subject: 'Kaban Backup - $name',
        sharePositionOrigin: origin,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e')),
        );
      }
    }
  }

  Future<void> _importBackup(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Import backup?'),
        content: const Text(
            'This replaces everything currently in the app with the contents '
            'of the backup file. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Import Backup')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (file == null) return;
      final data = json.decode(utf8.decode(await file.readAsBytes()))
          as Map<String, dynamic>;
      await ref.read(backupServiceProvider).import(data);
      await Future.wait([
        ref.read(walletListProvider.notifier).load(),
        ref.read(transactionListProvider.notifier).load(),
        ref.read(debtListProvider.notifier).load(),
        ref.read(goalListProvider.notifier).load(),
        ref.read(budgetListProvider.notifier).load(),
        ref.read(subscriptionListProvider.notifier).load(),
        ref.read(recurringListProvider.notifier).load(),
        ref.read(notificationEventListProvider.notifier).load(),
        ref.read(chatListProvider.notifier).load(),
      ]);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup restored.')),
        );
      }
    } on FormatException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That file is not a Kaban backup.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  Widget _section(String title, ThemeData t) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        title.toUpperCase(),
        style: t.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: t.colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ModelField extends StatelessWidget {
  final String currentModelId;
  final ValueChanged<String> onPick;
  final AIProvider provider;
  final String? apiKey;
  final String? baseUrl;
  final ThemeData t;
  const _ModelField({
    required this.currentModelId,
    required this.onPick,
    required this.provider,
    this.apiKey,
    this.baseUrl,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final preset = findModelPreset(currentModelId);
    final name =
        preset?.name ?? (currentModelId.isEmpty ? 'Not set' : currentModelId);
    final tagline = preset?.tagline ??
        'Custom model ID. Tap to pick from the curated list.';
    final presets = presetsFor(provider);
    final hint = presets.isEmpty
        ? 'No curated list for this provider — type any OpenAI-shape model ID.'
        : 'OpenAI-compatible models for ${kAIProviders[provider]!.displayName}.';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => ModelPicker.show(
          context,
          currentModelId: currentModelId,
          onSelected: onPick,
          presets: presets,
          headerHint: hint,
          provider: provider,
          apiKey: apiKey,
          baseUrl: baseUrl,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: t.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.tune_rounded,
                  size: 18, color: t.colorScheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Text(
                          currentModelId,
                          style: t.textTheme.labelSmall?.copyWith(
                            color: t.colorScheme.onSurfaceVariant,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tagline,
                      style: t.textTheme.bodySmall?.copyWith(
                        color: t.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded,
                  color: t.colorScheme.onSurfaceVariant, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
