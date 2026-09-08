import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_settings.dart';
import 'finance_providers.dart';

class SettingsNotifier extends StateNotifier<AppSettings> {
  final SettingsService _service;
  SettingsNotifier(this._service) : super(const AppSettings());

  Future<void> load() async {
    state = await _service.load();
  }

  Future<void> update(AppSettings next) async {
    state = next;
    await _service.save(next);
  }
}

final settingsServiceProvider =
    Provider<SettingsService>((ref) => SettingsService());

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier(ref.watch(settingsServiceProvider));
});
