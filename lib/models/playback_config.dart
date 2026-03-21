enum AffirmationMode { you, normal }
enum NarratorType { voicevox, tts }
enum RepeatMode { none, one, all }

class PlaybackConfig {
  const PlaybackConfig({
    required this.mode,
    required this.defaultFirstPerson,
    required this.narratorId,
    required this.narratorType,
    required this.bgmId,
    required this.bgmVolume,
    required this.voiceVolume,
    required this.sentenceGapMs,
    required this.startDelayMs,
    required this.speechRate,
    required this.shuffle,
    required this.repeatMode,
    required this.headphoneAutoPause,
  });

  final AffirmationMode mode;
  final String defaultFirstPerson;
  final String narratorId;
  final NarratorType narratorType;
  final String? bgmId;
  final double bgmVolume;
  final double voiceVolume;
  final int sentenceGapMs;
  final int startDelayMs;
  final double speechRate;
  final bool shuffle;
  final RepeatMode repeatMode;
  final bool headphoneAutoPause;

  factory PlaybackConfig.defaults() {
    return const PlaybackConfig(
      mode: AffirmationMode.normal,
      defaultFirstPerson: '私',
      narratorId: 'tts:default',
      narratorType: NarratorType.tts,
      bgmId: null,
      bgmVolume: 0.35,
      voiceVolume: 1,
      sentenceGapMs: 1200,
      startDelayMs: 3000,
      speechRate: 1.0,
      shuffle: false,
      repeatMode: RepeatMode.none,
      headphoneAutoPause: true,
    );
  }

  PlaybackConfig copyWith({
    AffirmationMode? mode,
    String? defaultFirstPerson,
    String? narratorId,
    NarratorType? narratorType,
    String? bgmId,
    double? bgmVolume,
    double? voiceVolume,
    int? sentenceGapMs,
    int? startDelayMs,
    double? speechRate,
    bool? shuffle,
    RepeatMode? repeatMode,
    bool? headphoneAutoPause,
  }) {
    return PlaybackConfig(
      mode: mode ?? this.mode,
      defaultFirstPerson: defaultFirstPerson ?? this.defaultFirstPerson,
      narratorId: narratorId ?? this.narratorId,
      narratorType: narratorType ?? this.narratorType,
      bgmId: bgmId ?? this.bgmId,
      bgmVolume: bgmVolume ?? this.bgmVolume,
      voiceVolume: voiceVolume ?? this.voiceVolume,
      sentenceGapMs: sentenceGapMs ?? this.sentenceGapMs,
      startDelayMs: startDelayMs ?? this.startDelayMs,
      speechRate: speechRate ?? this.speechRate,
      shuffle: shuffle ?? this.shuffle,
      repeatMode: repeatMode ?? this.repeatMode,
      headphoneAutoPause: headphoneAutoPause ?? this.headphoneAutoPause,
    );
  }

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'defaultFirstPerson': defaultFirstPerson,
        'narratorId': narratorId,
        'narratorType': narratorType.name,
        'bgmId': bgmId,
        'bgmVolume': bgmVolume,
        'voiceVolume': voiceVolume,
        'sentenceGapMs': sentenceGapMs,
        'startDelayMs': startDelayMs,
        'speechRate': speechRate,
        'shuffle': shuffle,
        'repeatMode': repeatMode.name,
        'headphoneAutoPause': headphoneAutoPause,
      };

  factory PlaybackConfig.fromJson(Map<String, dynamic> json) {
    return PlaybackConfig(
      mode: AffirmationMode.values.firstWhere(
        (item) => item.name == json['mode'],
        orElse: () => AffirmationMode.normal,
      ),
      defaultFirstPerson: json['defaultFirstPerson'] as String? ?? '私',
      narratorId: json['narratorId'] as String? ?? 'tts:default',
      narratorType: NarratorType.values.firstWhere(
        (item) => item.name == json['narratorType'],
        orElse: () => NarratorType.tts,
      ),
      bgmId: json['bgmId'] as String?,
      bgmVolume: (json['bgmVolume'] as num?)?.toDouble() ?? 0.35,
      voiceVolume: (json['voiceVolume'] as num?)?.toDouble() ?? 1,
      sentenceGapMs: json['sentenceGapMs'] as int? ?? 1200,
      startDelayMs: json['startDelayMs'] as int? ?? 3000,
      speechRate: (json['speechRate'] as num?)?.toDouble() ?? 1.0,
      shuffle: json['shuffle'] as bool? ?? false,
      repeatMode: RepeatMode.values.firstWhere(
        (item) => item.name == json['repeatMode'],
        orElse: () => RepeatMode.none,
      ),
      headphoneAutoPause: json['headphoneAutoPause'] as bool? ?? true,
    );
  }
}

class PlaybackConfigPreset {
  const PlaybackConfigPreset({
    required this.name,
    required this.config,
  });

  final String name;
  final PlaybackConfig config;

  Map<String, dynamic> toJson() => {
        'name': name,
        'config': config.toJson(),
      };

  factory PlaybackConfigPreset.fromJson(Map<String, dynamic> json) {
    return PlaybackConfigPreset(
      name: json['name'] as String,
      config: PlaybackConfig.fromJson(json['config'] as Map<String, dynamic>),
    );
  }
}
