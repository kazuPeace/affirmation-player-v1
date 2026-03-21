import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/playback_config.dart';

class SharedPrefsSettingsRepository {
  SharedPrefsSettingsRepository(this._preferences);

  static const _lastConfigKey = 'settings.lastConfig';
  static const _presetsKey = 'settings.presets';

  final SharedPreferences _preferences;

  Future<PlaybackConfig> loadLastConfig() async {
    final raw = _preferences.getString(_lastConfigKey);
    if (raw == null || raw.isEmpty) {
      return PlaybackConfig.defaults();
    }
    return PlaybackConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveLastConfig(PlaybackConfig config) async {
    await _preferences.setString(_lastConfigKey, jsonEncode(config.toJson()));
  }

  Future<List<PlaybackConfigPreset>> loadPresets() async {
    final raw = _preferences.getString(_presetsKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => PlaybackConfigPreset.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<PlaybackConfigPreset>> savePreset(
    String name,
    PlaybackConfig config,
  ) async {
    final current = await loadPresets();
    final sanitized = name.trim().isEmpty ? 'My Preset' : name.trim();
    current.removeWhere((item) => item.name == sanitized);
    current.insert(0, PlaybackConfigPreset(name: sanitized, config: config));
    await _preferences.setString(
      _presetsKey,
      jsonEncode(current.map((item) => item.toJson()).toList()),
    );
    return current;
  }

  static Future<void> seedDefaultIfNeeded(PlaybackConfig config) async {
    final preferences = await SharedPreferences.getInstance();
    if (!preferences.containsKey(_lastConfigKey)) {
      await preferences.setString(_lastConfigKey, jsonEncode(config.toJson()));
    }
  }
}
