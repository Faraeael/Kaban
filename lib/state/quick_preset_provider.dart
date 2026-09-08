import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/quick_preset.dart';

const _kPrefsKey = 'quick_presets';
const _kQuickLogChannel = 'finance_tracker/quick_log';

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class QuickPresetNotifier extends StateNotifier<List<QuickPreset>> {
  static const _channel = MethodChannel(_kQuickLogChannel);

  QuickPresetNotifier() : super(kDefaultQuickPresets) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kPrefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        state = raw.map((s) => QuickPreset.fromJson(s)).toList();
      } catch (_) {
        // corrupt data — fall back to defaults
        state = kDefaultQuickPresets;
      }
    }
    await _syncToAndroid();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _kPrefsKey, state.map((p) => p.toJson()).toList());
    await _syncToAndroid();
  }

  /// Pushes the top-4 presets to the Android Home Screen widget via
  /// MethodChannel so the AppWidgetProvider can read them from
  /// SharedPreferences without a running Flutter engine.
  Future<void> _syncToAndroid() async {
    try {
      final top4 = state.take(4).toList();
      await _channel.invokeMethod<void>('syncPresets', {
        'presets': top4
            .map((p) => {
                  'id': p.id,
                  'icon': p.icon,
                  'label': p.label,
                  'amount': p.amount,
                  'category': p.category,
                  if (p.walletId != null) 'walletId': p.walletId,
                })
            .toList(),
      });
    } on MissingPluginException {
      // Running in test / desktop — no Android channel, ignore.
    } catch (_) {
      // Best-effort; widget will show stale data until next sync.
    }
  }

  // ---------------------------------------------------------------------------
  // Public mutations
  // ---------------------------------------------------------------------------

  Future<void> add(QuickPreset preset) async {
    state = [...state, preset];
    await _save();
  }

  Future<void> update(QuickPreset preset) async {
    state = state.map((p) => p.id == preset.id ? preset : p).toList();
    await _save();
  }

  Future<void> remove(String id) async {
    state = state.where((p) => p.id != id).toList();
    await _save();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final list = [...state];
    if (newIndex > oldIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = list;
    await _save();
  }

  Future<void> reset() async {
    state = kDefaultQuickPresets;
    await _save();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final quickPresetProvider =
    StateNotifierProvider<QuickPresetNotifier, List<QuickPreset>>(
  (ref) => QuickPresetNotifier(),
);

// ---------------------------------------------------------------------------
// Helper: parse an incoming quick-log intent from the Android widget
// ---------------------------------------------------------------------------

/// Decodes the JSON string sent by the Android BroadcastReceiver.
/// Returns null if the payload is malformed.
QuickPreset? parseQuickLogIntent(String? json) {
  if (json == null) return null;
  try {
    final m = jsonDecode(json) as Map<String, Object?>;
    return QuickPreset.fromMap(m);
  } catch (_) {
    return null;
  }
}
