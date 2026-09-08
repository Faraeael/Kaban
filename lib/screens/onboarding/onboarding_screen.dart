import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/ai/ai_provider_config.dart';
import '../../state/data_providers.dart';
import '../../state/settings_provider.dart';
import '../settings/widgets/model_picker.dart';
import 'widgets/test_api_button.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < 1) {
      HapticFeedback.selectionClick();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  void _back() {
    if (_page > 0) {
      HapticFeedback.selectionClick();
      _pageController.previousPage(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _finish() async {
    HapticFeedback.lightImpact();
    await ref.read(settingsProvider.notifier).update(
          ref.read(settingsProvider).copyWith(onboardingComplete: true),
        );
    if (mounted) context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      backgroundColor: t.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
              child: Row(
                children: [
                  AnimatedDots(
                      active: _page,
                      count: 2,
                      color: t.colorScheme.primary,
                      dim: t.colorScheme.outlineVariant),
                  const Spacer(),
                  if (_page < 1)
                    TextButton(
                      onPressed: _finish,
                      style: TextButton.styleFrom(
                        foregroundColor: t.colorScheme.onSurfaceVariant,
                      ),
                      child: const Text('Skip for now'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _page = i),
                physics: const NeverScrollableScrollPhysics(),
                children: const [
                  _WalletIntroPage(),
                  _CoachIntroPage(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Row(
                children: [
                  if (_page > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _back,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                  if (_page > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _next,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(_page == 1 ? "I'm ready" : 'Continue'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AnimatedDots extends StatelessWidget {
  final int active;
  final int count;
  final Color color;
  final Color dim;
  const AnimatedDots(
      {super.key,
      required this.active,
      required this.count,
      required this.color,
      required this.dim});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(count, (i) {
        final on = i == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.only(right: 6),
          height: 6,
          width: on ? 22 : 8,
          decoration: BoxDecoration(
            color: on ? color : dim,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

// ============================================================================
// Page 1 — Tell the user what the app is, then get them straight to the
//           action that proves it (adding a wallet). Skip the feature list.
// ============================================================================

class _WalletIntroPage extends ConsumerWidget {
  const _WalletIntroPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final wallets = ref.watch(walletListProvider);
    final balances = ref.watch(walletBalancesProvider);
    final monthSummary = ref.watch(monthSummaryProvider);
    final hasData = wallets.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'Your money,\non one screen.',
            style: t.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              height: 1.05,
              color: t.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Track every wallet — banks, e-wallets, credit, cash — and see '
            'your real net worth without sending a byte to the cloud.',
            style: t.textTheme.bodyMedium?.copyWith(
              color: t.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _DashboardPreview(
              hasData: hasData,
              walletCount: wallets.length,
              sampleWallet: wallets.isEmpty ? null : wallets.first.name,
              sampleBalance:
                  wallets.isEmpty ? 0 : (balances[wallets.first.id] ?? 0),
              income: monthSummary.income,
              expense: monthSummary.expense,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: t.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: t.colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_outline_rounded,
                    size: 18, color: t.colorScheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'On-device only. No ads, no accounts, no telemetry.',
                    style: t.textTheme.bodySmall?.copyWith(
                      color: t.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardPreview extends StatelessWidget {
  final bool hasData;
  final int walletCount;
  final String? sampleWallet;
  final double sampleBalance;
  final double income;
  final double expense;

  const _DashboardPreview({
    required this.hasData,
    required this.walletCount,
    required this.sampleWallet,
    required this.sampleBalance,
    required this.income,
    required this.expense,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    const weight = FontWeight.w800;
    final dimStyle = t.textTheme.bodySmall?.copyWith(
      color: t.colorScheme.onSurfaceVariant,
      letterSpacing: 0.4,
    );

    return Container(
      decoration: BoxDecoration(
        color: t.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: t.colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NET WORTH',
              style: dimStyle?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            hasData ? pesoDisplay(sampleBalance) : '₱0',
            style: t.textTheme.displayMedium?.copyWith(
              fontWeight: weight,
              letterSpacing: -1,
              color: hasData
                  ? t.colorScheme.onSurface
                  : t.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatBlock(
                  label: 'WALLETS',
                  value: hasData ? '$walletCount' : '—',
                ),
              ),
              Expanded(
                child: _StatBlock(
                  label: 'IN',
                  value: hasData ? pesoCompact(income) : '₱0',
                  color: t.colorScheme.primary,
                ),
              ),
              Expanded(
                child: _StatBlock(
                  label: 'OUT',
                  value: hasData ? pesoCompact(expense) : '₱0',
                  color: t.colorScheme.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _StatBlock({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: t.textTheme.labelSmall?.copyWith(
            color: t.colorScheme.onSurfaceVariant,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: t.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: color ?? t.colorScheme.onSurface,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

String pesoDisplay(double v) {
  final neg = v < 0;
  final n = v.abs();
  return '${neg ? '-' : ''}₱${n.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';
}

String pesoCompact(double v) {
  final n = v.abs();
  if (n >= 1000000) return '₱${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '₱${(n / 1000).toStringAsFixed(1)}k';
  return '₱${n.toStringAsFixed(0)}';
}

// ============================================================================
// Page 2 — Coach choice. Default to Local (no setup) but show the trade-off
//           inline. Don't make API key a first-class obstacle on first run.
// ============================================================================

class _CoachIntroPage extends ConsumerStatefulWidget {
  const _CoachIntroPage();

  @override
  ConsumerState<_CoachIntroPage> createState() => _CoachIntroPageState();
}

class _CoachIntroPageState extends ConsumerState<_CoachIntroPage> {
  late TextEditingController _apiKey;

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    _apiKey = TextEditingController(text: s.aiApiKey);
  }

  @override
  void dispose() {
    _apiKey.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final provider = settings.aiProvider;
    final isLocal = provider == AIProvider.local;
    final config = kAIProviders[provider]!;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How smart should\nyour coach be?',
            style: t.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'You can change this any time in Settings.',
            style: t.textTheme.bodyMedium?.copyWith(
              color: t.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          _CoachChoiceTile(
            selected: isLocal,
            title: 'On-device (offline)',
            subtitle:
                'Works without internet. Quick answers from your own rules.',
            pill: 'No setup',
            onTap: () => notifier.update(settings.copyWith(
              aiProvider: AIProvider.local,
              allowRemoteAI: false,
            )),
          ),
          const SizedBox(height: 10),
          _ProviderPickerRow(
            provider: provider,
            onPick: (p) {
              final cfg = kAIProviders[p]!;
              notifier.update(settings.copyWith(
                aiProvider: p,
                aiBaseUrl: cfg.defaultBaseUrl ?? settings.aiBaseUrl,
                aiModel: cfg.defaultModel ?? settings.aiModel,
                allowRemoteAI: true,
              ));
            },
          ),
          if (!isLocal) ...[
            const SizedBox(height: 18),
            Text(
              'API key',
              style:
                  t.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _apiKey,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Paste your key here',
                prefixIcon: const Icon(Icons.key_rounded, size: 18),
                suffixIcon: _apiKey.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.check_rounded, size: 18),
                        onPressed: () {
                          notifier.update(
                              settings.copyWith(aiApiKey: _apiKey.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('API key saved')),
                          );
                        },
                      ),
              ),
              onChanged: (v) {
                notifier.update(settings.copyWith(aiApiKey: v));
                setState(() {});
              },
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: t.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: t.colorScheme.outlineVariant.withValues(alpha: 0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.privacy_tip_outlined,
                      size: 18, color: t.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Balances rounded to ₱100, no merchant names, no notes. '
                      'You can switch back to on-device any time.',
                      style: t.textTheme.bodySmall?.copyWith(
                        color: t.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (!isLocal) ...[
            const SizedBox(height: 14),
            _OnboardingModelRow(
              currentModelId: settings.aiModel.isNotEmpty
                  ? settings.aiModel
                  : (config.defaultModel ?? ''),
              provider: provider,
              apiKey: _apiKey.text,
              baseUrl: settings.aiBaseUrl,
              onPick: (id) => notifier.update(settings.copyWith(aiModel: id)),
            ),
            const SizedBox(height: 12),
            TestApiButton(
              provider: provider,
              baseUrl: settings.aiBaseUrl.isNotEmpty
                  ? settings.aiBaseUrl
                  : (config.defaultBaseUrl ?? ''),
              apiKey: _apiKey.text,
              model: settings.aiModel.isNotEmpty
                  ? settings.aiModel
                  : (config.defaultModel ?? ''),
            ),
          ],
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Provider: ${config.displayName}',
              style: t.textTheme.bodySmall?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoachChoiceTile extends StatelessWidget {
  final bool selected;
  final String title;
  final String subtitle;
  final String pill;
  final VoidCallback onTap;
  const _CoachChoiceTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.pill,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? t.colorScheme.primaryContainer.withValues(alpha: 0.55)
                : t.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? t.colorScheme.primary
                  : t.colorScheme.outlineVariant.withValues(alpha: 0.4),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? t.colorScheme.primary : t.colorScheme.outline,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: t.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: t.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            pill,
                            style: t.textTheme.labelSmall?.copyWith(
                              color: t.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: t.textTheme.bodySmall?.copyWith(
                        color: t.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingModelRow extends StatelessWidget {
  final String currentModelId;
  final AIProvider provider;
  final String? apiKey;
  final String? baseUrl;
  final ValueChanged<String> onPick;
  const _OnboardingModelRow({
    required this.currentModelId,
    required this.provider,
    this.apiKey,
    this.baseUrl,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final preset = findModelPreset(currentModelId);
    final name =
        preset?.name ?? (currentModelId.isEmpty ? 'Not set' : currentModelId);
    final presets = presetsFor(provider);
    final hint = presets.isEmpty
        ? 'No curated list for this provider.'
        : 'OpenAI-compatible models for ${kAIProviders[provider]!.displayName}.';

    return InkWell(
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
          border: Border.all(
              color: t.colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.tune_rounded,
                size: 18, color: t.colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Model',
                    style: t.textTheme.labelSmall?.copyWith(
                      color: t.colorScheme.onSurfaceVariant,
                      letterSpacing: 0.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: t.colorScheme.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ProviderPickerRow extends StatelessWidget {
  final AIProvider provider;
  final ValueChanged<AIProvider> onPick;
  const _ProviderPickerRow({required this.provider, required this.onPick});

  Future<void> _open(BuildContext context) async {
    HapticFeedback.selectionClick();
    final picked = await showModalBottomSheet<AIProvider>(
      context: context,
      showDragHandle: true,
      builder: (_) => _ProviderSheet(current: provider, onPick: onPick),
    );
    if (picked != null) onPick(picked);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final config = kAIProviders[provider]!;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _open(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: t.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.cloud_outlined, size: 22, color: t.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Remote provider',
                          style: t.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: t.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Needs API key',
                          style: t.textTheme.labelSmall?.copyWith(
                            color: t.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Richer answers from your real numbers. Sends only an anonymized snapshot.',
                    style: t.textTheme.bodySmall?.copyWith(
                      color: t.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        config.displayName,
                        style: t.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: t.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.unfold_more_rounded,
                          size: 16, color: t.colorScheme.primary),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderSheet extends StatefulWidget {
  final AIProvider current;
  final ValueChanged<AIProvider> onPick;
  const _ProviderSheet({required this.current, required this.onPick});

  @override
  State<_ProviderSheet> createState() => _ProviderSheetState();
}

class _ProviderSheetState extends State<_ProviderSheet> {
  late AIProvider _selected = widget.current;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final remoteProviders =
        kAIProviders.entries.where((e) => e.key != AIProvider.local).toList();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose a remote provider',
                style: t.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'All remote providers send an anonymized snapshot — no merchant names, '
                'balances rounded to ₱100 by default.',
                style: t.textTheme.bodySmall?.copyWith(
                  color: t.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final entry in remoteProviders) ...[
                        _ProviderRow(
                          provider: entry.key,
                          config: entry.value,
                          selected: _selected == entry.key,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selected = entry.key);
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, _selected),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Use this'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProviderRow extends StatelessWidget {
  final AIProvider provider;
  final AIProviderConfig config;
  final bool selected;
  final VoidCallback onTap;
  const _ProviderRow({
    required this.provider,
    required this.config,
    required this.selected,
    required this.onTap,
  });

  IconData _iconFor(AIProvider p) {
    switch (p) {
      case AIProvider.commandcode:
        return Icons.bolt_rounded;
      case AIProvider.opencode:
        return Icons.code_rounded;
      case AIProvider.openrouter:
        return Icons.route_rounded;
      case AIProvider.google:
        return Icons.auto_awesome_rounded;
      case AIProvider.local:
        return Icons.phone_android_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? t.colorScheme.primaryContainer.withValues(alpha: 0.55)
                : t.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? t.colorScheme.primary
                  : t.colorScheme.outlineVariant.withValues(alpha: 0.4),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? t.colorScheme.primary : t.colorScheme.outline,
                size: 20,
              ),
              const SizedBox(width: 10),
              Icon(_iconFor(provider),
                  size: 20, color: t.colorScheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      config.displayName,
                      style: t.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      config.docsHint,
                      style: t.textTheme.bodySmall?.copyWith(
                        color: t.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
