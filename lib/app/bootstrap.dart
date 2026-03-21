import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/constants.dart';
import '../data/repositories/affirmation_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../models/affirmation.dart';
import '../models/playback_config.dart';
import '../services/audio/affirmation_audio_handler.dart';
import '../services/audio/playback_coordinator.dart';
import '../services/speech/sentence_synthesis_pipeline.dart';
import '../services/speech/tts_file_engine.dart';
import '../services/speech/voicevox_local_engine.dart';
import 'providers.dart';

class AppBootstrap {
  AppBootstrap._(this.overrides);

  final List<Override> overrides;

  static Future<AppBootstrap> initialize() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final cacheDirectory = await getApplicationCacheDirectory();
    final preferences = await SharedPreferences.getInstance();

    final affirmationRepository = JsonAffirmationRepository(
      storageFile: File('${documentsDirectory.path}/affirmations.json'),
    );
    final settingsRepository = SharedPrefsSettingsRepository(preferences);

    final ttsEngine = TtsFileEngine();
    final voicevoxEngine = VoicevoxLocalEngine();
    final playbackCoordinator = PlaybackCoordinator();
    final synthesisPipeline = SentenceSynthesisPipeline(
      cacheDirectory: Directory('${documentsDirectory.path}/audio_cache'),
      voicevoxEngine: voicevoxEngine,
      ttsEngine: ttsEngine,
      playbackCoordinator: playbackCoordinator,
    );

    await _seedSampleAffirmations(affirmationRepository);

    final audioHandler = await AudioService.init<AffirmationAudioHandler>(
      builder: () => AffirmationAudioHandler(
        affirmationRepository: affirmationRepository,
        synthesisPipeline: synthesisPipeline,
        playbackCoordinator: playbackCoordinator,
      ),
      config: AudioServiceConfig(
        androidNotificationChannelId: 'affirmation_player.playback',
        androidNotificationChannelName: 'Affirmation Playback',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        preloadArtwork: true,
      ),
    );

    return AppBootstrap._([
      documentsDirectoryProvider.overrideWithValue(documentsDirectory),
      cacheDirectoryProvider.overrideWithValue(cacheDirectory),
      affirmationRepositoryProvider.overrideWithValue(affirmationRepository),
      settingsRepositoryProvider.overrideWithValue(settingsRepository),
      ttsEngineProvider.overrideWithValue(ttsEngine),
      voicevoxEngineProvider.overrideWithValue(voicevoxEngine),
      playbackCoordinatorProvider.overrideWithValue(playbackCoordinator),
      synthesisPipelineProvider.overrideWithValue(synthesisPipeline),
      audioHandlerProvider.overrideWithValue(audioHandler),
    ]);
  }

  static Future<void> _seedSampleAffirmations(
    JsonAffirmationRepository repository,
  ) async {
    final existing = await repository.fetchAll();
    if (existing.isNotEmpty) {
      return;
    }

    final now = DateTime.now();
    const uuid = Uuid();
    final samples = [
      Affirmation(
        id: uuid.v4(),
        title: '深呼吸して整える朝',
        note: '朝の切り替え用プレイリスト',
        tags: const ['朝', '集中'],
        sentences: [
          AffirmationSentence(
            id: uuid.v4(),
            order: 0,
            subjectText: '私は',
            predicateText: '穏やかな気持ちで今日を始める',
          ),
          AffirmationSentence(
            id: uuid.v4(),
            order: 1,
            subjectText: '私は',
            predicateText: '必要なことに落ち着いて集中できる',
          ),
          AffirmationSentence(
            id: uuid.v4(),
            order: 2,
            subjectText: '私は',
            predicateText: '自分の選択を信頼して進んでいく',
          ),
        ],
        isFavorite: true,
        playCount: 0,
        lastPlayedAt: null,
        createdAt: now,
        updatedAt: now,
      ),
      Affirmation(
        id: uuid.v4(),
        title: 'セルフラブの夜',
        note: '一日をやさしく締めくくる',
        tags: const ['夜', 'セルフケア'],
        sentences: [
          AffirmationSentence(
            id: uuid.v4(),
            order: 0,
            subjectText: '私は',
            predicateText: '今日もよく頑張った',
          ),
          AffirmationSentence(
            id: uuid.v4(),
            order: 1,
            subjectText: '私は',
            predicateText: '安心して休み、明日に力をためる',
          ),
          AffirmationSentence(
            id: uuid.v4(),
            order: 2,
            subjectText: '私は',
            predicateText: '自分にやさしい言葉をかけ続ける',
          ),
        ],
        isFavorite: false,
        playCount: 0,
        lastPlayedAt: null,
        createdAt: now,
        updatedAt: now,
      ),
      Affirmation(
        id: uuid.v4(),
        title: 'YOU モードの後押し',
        note: '背中を押してほしい時に',
        tags: const ['YOU', '勇気'],
        sentences: [
          AffirmationSentence(
            id: uuid.v4(),
            order: 0,
            subjectText: '',
            predicateText: '必要な力をすでに持っている',
          ),
          AffirmationSentence(
            id: uuid.v4(),
            order: 1,
            subjectText: '',
            predicateText: '一歩ずつ前へ進めている',
          ),
          AffirmationSentence(
            id: uuid.v4(),
            order: 2,
            subjectText: '',
            predicateText: '今日の選択が未来をやさしく変えていく',
          ),
        ],
        isFavorite: false,
        playCount: 0,
        lastPlayedAt: null,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    for (final sample in samples) {
      await repository.save(sample);
    }

    final config = PlaybackConfig.defaults().copyWith(
      bgmId: AppBgmCatalog.tracks.first.id,
    );
    await SharedPrefsSettingsRepository.seedDefaultIfNeeded(config);
  }
}
