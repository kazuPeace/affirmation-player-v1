import 'playback_config.dart';

class PlaybackSessionState {
  const PlaybackSessionState({
    required this.currentAffirmationId,
    required this.currentAffirmationTitle,
    required this.currentSentenceIndex,
    required this.totalSentenceCount,
    required this.isPlaying,
    required this.currentRenderedText,
    required this.queueAffirmationIds,
    required this.startedAt,
    required this.sleepTimerEndsAt,
    required this.mode,
    required this.repeatMode,
    required this.shuffle,
    required this.bgmName,
    required this.narratorName,
    required this.bgmVolume,
    required this.voiceVolume,
    required this.speechRate,
    required this.currentSentenceDuration,
    required this.currentSentencePosition,
    required this.errorMessage,
  });

  final String? currentAffirmationId;
  final String currentAffirmationTitle;
  final int currentSentenceIndex;
  final int totalSentenceCount;
  final bool isPlaying;
  final String currentRenderedText;
  final List<String> queueAffirmationIds;
  final DateTime? startedAt;
  final DateTime? sleepTimerEndsAt;
  final AffirmationMode mode;
  final RepeatMode repeatMode;
  final bool shuffle;
  final String bgmName;
  final String narratorName;
  final double bgmVolume;
  final double voiceVolume;
  final double speechRate;
  final Duration currentSentenceDuration;
  final Duration currentSentencePosition;
  final String? errorMessage;

  factory PlaybackSessionState.idle() {
    return const PlaybackSessionState(
      currentAffirmationId: null,
      currentAffirmationTitle: '未再生',
      currentSentenceIndex: 0,
      totalSentenceCount: 0,
      isPlaying: false,
      currentRenderedText: '',
      queueAffirmationIds: [],
      startedAt: null,
      sleepTimerEndsAt: null,
      mode: AffirmationMode.normal,
      repeatMode: RepeatMode.none,
      shuffle: false,
      bgmName: 'なし',
      narratorName: '未選択',
      bgmVolume: 0.35,
      voiceVolume: 1,
      speechRate: 1.0,
      currentSentenceDuration: Duration.zero,
      currentSentencePosition: Duration.zero,
      errorMessage: null,
    );
  }

  PlaybackSessionState copyWith({
    String? currentAffirmationId,
    String? currentAffirmationTitle,
    int? currentSentenceIndex,
    int? totalSentenceCount,
    bool? isPlaying,
    String? currentRenderedText,
    List<String>? queueAffirmationIds,
    DateTime? startedAt,
    DateTime? sleepTimerEndsAt,
    AffirmationMode? mode,
    RepeatMode? repeatMode,
    bool? shuffle,
    String? bgmName,
    String? narratorName,
    double? bgmVolume,
    double? voiceVolume,
    double? speechRate,
    Duration? currentSentenceDuration,
    Duration? currentSentencePosition,
    String? errorMessage,
  }) {
    return PlaybackSessionState(
      currentAffirmationId: currentAffirmationId ?? this.currentAffirmationId,
      currentAffirmationTitle:
          currentAffirmationTitle ?? this.currentAffirmationTitle,
      currentSentenceIndex: currentSentenceIndex ?? this.currentSentenceIndex,
      totalSentenceCount: totalSentenceCount ?? this.totalSentenceCount,
      isPlaying: isPlaying ?? this.isPlaying,
      currentRenderedText: currentRenderedText ?? this.currentRenderedText,
      queueAffirmationIds: queueAffirmationIds ?? this.queueAffirmationIds,
      startedAt: startedAt ?? this.startedAt,
      sleepTimerEndsAt: sleepTimerEndsAt ?? this.sleepTimerEndsAt,
      mode: mode ?? this.mode,
      repeatMode: repeatMode ?? this.repeatMode,
      shuffle: shuffle ?? this.shuffle,
      bgmName: bgmName ?? this.bgmName,
      narratorName: narratorName ?? this.narratorName,
      bgmVolume: bgmVolume ?? this.bgmVolume,
      voiceVolume: voiceVolume ?? this.voiceVolume,
      speechRate: speechRate ?? this.speechRate,
      currentSentenceDuration:
          currentSentenceDuration ?? this.currentSentenceDuration,
      currentSentencePosition:
          currentSentencePosition ?? this.currentSentencePosition,
      errorMessage: errorMessage,
    );
  }
}
