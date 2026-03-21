import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../data/repositories/affirmation_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../models/affirmation.dart';
import '../models/bgm_track.dart';
import '../models/narrator_option.dart';
import '../models/playback_config.dart';
import '../models/playback_session_state.dart';
import '../services/audio/affirmation_audio_handler.dart';
import '../services/audio/playback_coordinator.dart';
import '../services/speech/sentence_synthesis_pipeline.dart';
import '../services/speech/tts_file_engine.dart';
import '../services/speech/voicevox_local_engine.dart';

final documentsDirectoryProvider = Provider<Directory>(
  (_) => throw UnimplementedError(),
);
final cacheDirectoryProvider = Provider<Directory>(
  (_) => throw UnimplementedError(),
);
final preferencesProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError(),
);
final affirmationRepositoryProvider = Provider<JsonAffirmationRepository>(
  (_) => throw UnimplementedError(),
);
final settingsRepositoryProvider = Provider<SharedPrefsSettingsRepository>(
  (_) => throw UnimplementedError(),
);
final ttsEngineProvider = Provider<TtsFileEngine>((_) => throw UnimplementedError());
final voicevoxEngineProvider = Provider<VoicevoxLocalEngine>(
  (_) => throw UnimplementedError(),
);
final playbackCoordinatorProvider = Provider<PlaybackCoordinator>(
  (_) => throw UnimplementedError(),
);
final synthesisPipelineProvider = Provider<SentenceSynthesisPipeline>(
  (_) => throw UnimplementedError(),
);
final audioHandlerProvider = Provider<AffirmationAudioHandler>(
  (_) => throw UnimplementedError(),
);

final librarySearchProvider = StateProvider<String>((_) => '');
final librarySortProvider = StateProvider<LibrarySort>((_) => LibrarySort.updatedAt);
final configExpandedProvider = StateProvider<bool>((_) => true);

enum LibrarySort { updatedAt, title, playCount }

class LibraryController extends AsyncNotifier<List<Affirmation>> {
  JsonAffirmationRepository get _repository => ref.read(affirmationRepositoryProvider);

  @override
  Future<List<Affirmation>> build() => _load();

  Future<List<Affirmation>> _load() async {
    final items = await _repository.fetchAll();
    return items;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _load());
  }

  Future<void> save(Affirmation affirmation) async {
    await _repository.save(affirmation);
    await refresh();
  }

  Future<void> delete(String id) async {
    await _repository.delete(id);
    await refresh();
  }

  Future<void> duplicate(Affirmation affirmation) async {
    await _repository.save(affirmation.duplicate());
    await refresh();
  }

  Future<void> toggleFavorite(Affirmation affirmation) async {
    await _repository.save(
      affirmation.copyWith(
        isFavorite: !affirmation.isFavorite,
        updatedAt: DateTime.now(),
      ),
    );
    await refresh();
  }

  Future<void> recordPlayback(Affirmation affirmation) async {
    await _repository.save(
      affirmation.copyWith(
        playCount: affirmation.playCount + 1,
        lastPlayedAt: DateTime.now(),
      ),
    );
    await refresh();
  }
}

final libraryControllerProvider =
    AsyncNotifierProvider<LibraryController, List<Affirmation>>(LibraryController.new);

final filteredLibraryProvider = Provider<List<Affirmation>>((ref) {
  final library = ref.watch(libraryControllerProvider).valueOrNull ?? const <Affirmation>[];
  final search = ref.watch(librarySearchProvider).trim().toLowerCase();
  final sort = ref.watch(librarySortProvider);
  final filtered = library.where((affirmation) {
    if (search.isEmpty) {
      return true;
    }
    final haystack = [
      affirmation.title,
      affirmation.note ?? '',
      ...affirmation.tags,
    ].join(' ').toLowerCase();
    return haystack.contains(search);
  }).toList();

  filtered.sort((a, b) {
    switch (sort) {
      case LibrarySort.title:
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      case LibrarySort.playCount:
        return b.playCount.compareTo(a.playCount);
      case LibrarySort.updatedAt:
        return b.updatedAt.compareTo(a.updatedAt);
    }
  });
  return filtered;
});

class AppSettingsState {
  const AppSettingsState({
    required this.config,
    required this.presets,
    required this.narrators,
    required this.bgmTracks,
    required this.voicevoxAvailable,
    required this.voicevoxStatus,
  });

  final PlaybackConfig config;
  final List<PlaybackConfigPreset> presets;
  final List<NarratorOption> narrators;
  final List<BgmTrack> bgmTracks;
  final bool voicevoxAvailable;
  final String voicevoxStatus;

  AppSettingsState copyWith({
    PlaybackConfig? config,
    List<PlaybackConfigPreset>? presets,
    List<NarratorOption>? narrators,
    List<BgmTrack>? bgmTracks,
    bool? voicevoxAvailable,
    String? voicevoxStatus,
  }) {
    return AppSettingsState(
      config: config ?? this.config,
      presets: presets ?? this.presets,
      narrators: narrators ?? this.narrators,
      bgmTracks: bgmTracks ?? this.bgmTracks,
      voicevoxAvailable: voicevoxAvailable ?? this.voicevoxAvailable,
      voicevoxStatus: voicevoxStatus ?? this.voicevoxStatus,
    );
  }
}

class SettingsController extends AsyncNotifier<AppSettingsState> {
  SharedPrefsSettingsRepository get _repository => ref.read(settingsRepositoryProvider);
  VoicevoxLocalEngine get _voicevox => ref.read(voicevoxEngineProvider);
  TtsFileEngine get _tts => ref.read(ttsEngineProvider);

  @override
  Future<AppSettingsState> build() async {
    final config = await _repository.loadLastConfig();
    final presets = await _repository.loadPresets();

    final ttsNarrators = await _tts.fetchNarrators();
    var voicevoxNarrators = <NarratorOption>[];
    var voicevoxAvailable = false;
    var voicevoxStatus = 'VOICEVOX は Android でのみ利用できます';

    try {
      voicevoxNarrators = await _voicevox.fetchNarrators();
      voicevoxAvailable = voicevoxNarrators.isNotEmpty;
      voicevoxStatus = voicevoxAvailable
          ? 'VOICEVOX 接続済み'
          : 'VOICEVOX 話者が見つかりません';
    } catch (error) {
      voicevoxStatus = error.toString().replaceFirst('Exception: ', '');
    }

    final narrators = [...voicevoxNarrators, ...ttsNarrators];
    final resolvedNarrator = narrators.any((item) => item.id == config.narratorId)
        ? config
        : config.copyWith(
            narratorId: narrators.isNotEmpty ? narrators.first.id : 'tts:default',
            narratorType:
                narrators.isNotEmpty ? narrators.first.type : NarratorType.tts,
          );

    return AppSettingsState(
      config: resolvedNarrator,
      presets: presets,
      narrators: narrators,
      bgmTracks: AppBgmCatalog.tracks,
      voicevoxAvailable: voicevoxAvailable,
      voicevoxStatus: voicevoxStatus,
    );
  }

  Future<void> updateConfig(PlaybackConfig config) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }
    await _repository.saveLastConfig(config);
    state = AsyncData(current.copyWith(config: config));
  }

  Future<void> savePreset(String name) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }
    final presets = await _repository.savePreset(name, current.config);
    state = AsyncData(current.copyWith(presets: presets));
  }

  Future<void> applyPreset(PlaybackConfigPreset preset) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }
    await updateConfig(preset.config);
  }

  Future<void> refreshNarrators() async {
    final previous = state.valueOrNull;
    state = const AsyncLoading();
    state = AsyncData(await build());
    if (previous != null && state.valueOrNull != null) {
      await _repository.saveLastConfig(state.valueOrNull!.config);
    }
  }

  Future<void> clearAudioCache() async {
    await ref.read(synthesisPipelineProvider).clearCache();
  }
}

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, AppSettingsState>(
  SettingsController.new,
);

final playbackSessionProvider = StreamProvider<PlaybackSessionState>((ref) {
  return ref.watch(audioHandlerProvider).sessionStream;
});
