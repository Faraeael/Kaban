import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/ai/ai_provider_config.dart';
import '../../../services/ai/coach_tester.dart';

class TestApiButton extends StatefulWidget {
  final AIProvider provider;
  final String baseUrl;
  final String apiKey;
  final String model;
  const TestApiButton({
    super.key,
    required this.provider,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
  });

  @override
  State<TestApiButton> createState() => _TestApiButtonState();
}

class _TestApiButtonState extends State<TestApiButton> {
  final _tester = CoachTester();
  _TestState _state = const _TestIdle();

  @override
  void didUpdateWidget(covariant TestApiButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.baseUrl != widget.baseUrl ||
        oldWidget.apiKey != widget.apiKey ||
        oldWidget.model != widget.model ||
        oldWidget.provider != widget.provider) {
      setState(() {
        _state = const _TestIdle();
      });
    }
  }

  Future<void> _run() async {
    HapticFeedback.selectionClick();
    setState(() => _state = const _Testing());
    final config = kAIProviders[widget.provider];
    if (config == null) {
      setState(() => _state = const _TestDone(CoachTestResult.failure(
        'Unknown provider.',
        durationMs: 0,
      )));
      return;
    }
    final result = await _tester.ping(
      config: config,
      baseUrl: widget.baseUrl,
      apiKey: widget.apiKey,
      model: widget.model,
    );
    if (!mounted) return;
    if (result.ok) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
    setState(() => _state = _TestDone(result));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final state = _state;
    final isBusy = state is _Testing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: isBusy ? null : _run,
          icon: isBusy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.wifi_tethering_rounded, size: 18),
          label: Text(isBusy ? 'Testing…' : 'Test API'),
        ),
        if (state is _TestDone) ...[
          const SizedBox(height: 10),
          _StatusCard(result: state.result, t: t),
        ],
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  final CoachTestResult result;
  final ThemeData t;
  const _StatusCard({required this.result, required this.t});

  @override
  Widget build(BuildContext context) {
    final ok = result.ok;
    final bg = ok
        ? t.colorScheme.primaryContainer.withValues(alpha: 0.55)
        : t.colorScheme.errorContainer.withValues(alpha: 0.55);
    final fg = ok ? t.colorScheme.onPrimaryContainer : t.colorScheme.onErrorContainer;
    final icon = ok ? Icons.check_circle_rounded : Icons.error_rounded;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              result.message,
              style: t.textTheme.bodySmall?.copyWith(color: fg, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

sealed class _TestState {
  const _TestState();
}

class _TestIdle extends _TestState {
  const _TestIdle();
}

class _Testing extends _TestState {
  const _Testing();
}

class _TestDone extends _TestState {
  final CoachTestResult result;
  const _TestDone(this.result);
}
