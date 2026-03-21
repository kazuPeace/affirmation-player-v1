import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/constants.dart';
import '../../data/repositories/affirmation_repository.dart';
import '../../models/affirmation.dart';
import '../../models/bgm_track.dart';
import '../../models/narrator_option.dart';
import '../../models/playback_config.dart';
import '../../models/playback_session_state.dart';
import '../../models/rendered_sentence.dart';
import '../speech/sentence_synthesis_pipeline.dart';
import 'playback_coordinator.dart';

class AffirmationAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  AffirmationAudioHandler({
    required JsonAffirmationRepository affirmationRepository,
    required SentenceSynthesisPipeline synthesisPipeline,
    required PlaybackCoordinator playbackCoordinator,
  })  : _affirmationRepository = affirmationRepository,
        _synthesisPipeline = synthesisPipeline,
        _playbackCoordinator = playbackCoordinator {
    _configure();
  }

  final JsonAffirmationRepository _affirmationRepository;
  final SentenceSynthesisPipeline _synthesisPipeline;
  final PlaybackCoordinator _playbackCoordinator;
  final AudioPlayer _bgmPlayer = AudioPlayer();
  final AudioPlayer _voicePlayer = AudioPlayer();
  final _sessionController = StreamController<PlaybackSessionState>.broadcast();

  PlaybackSessionState _session = PlaybackSessionState.idle();
  List<Affirmation> _affirmationQueue = const [];
  List<RenderedSentence> _currentRendered = const [];
  List<NarratorOption> _narrators = const [];
  PlaybackConfig _config = PlaybackConfig.defaults();
  int _queueIndex = 0;
  int _sentenceStartIndex = 0;
  int _playToken = 0;
  bool _paused = false;
  bool _stopAfterCurrentSentence = false;
  Timer? _sleepTimer;

  Stream<PlaybackSessionState> get sessionStream => _sessionController.stream;
  PlaybackSessionState get currentSession => _session;

  Future<void> _configure() async {
    final audioSession = await AudioSession.instance;
    await audioSession.configure(
      const AudioSessionConfiguration.music(),
    );
    audioSession.becomingNoisyEventStream.listen((_) {
      if (_config.headphoneAutoPause) {
        pause();
      }
    });
    audioSession.interruptionEventStream.listen((event) {
      if (event.begin) {
        pause();
      } else if (!_paused) {
        play();
      }
    });

    _voicePlayer.positionStream.listen((position) {
      _setSession(
        _session.copyWith(
          currentSentencePosition: position,
          currentSentenceDuration: _voicePlayer.duration ?? Duration.zero,
        ),
      );
      _broadcastPlaybackState();
    });

    _voicePlayer.playerStateStream.listen((_) => _broadcastPlaybackState());
    _bgmPlayer.playerStateStream.listen((_) => _broadcastPlaybackState());
    _setSession(_session);
  }

  Future<void> startPlayback({
    required List<Affirmation> libraryQueue,
    required int startIndex,
    required PlaybackConfig config,
    required List<NarratorOption> narrators,
  }) async {
    _affirmationQueue = List<Affirmation>.from(libraryQueue);
    _config = config;
    _narrators = narrators;
    _queueIndex = startIndex.clamp(0, _affirmationQueue.length - 1);
    _sentenceStartIndex = 0;
    _paused = false;
    _stopAfterCurrentSentence = false;
    await _startNewRun();
  }

  Future<void> previewAffirmation({
    required Affirmation affirmation,
    required PlaybackConfig config,
    required List<NarratorOption> narrators,
  }) async {
    await startPlayback(
      libraryQueue: [affirmation],
      startIndex: 0,
      config: config,
      narrators: narrators,
    );
  }

  Future<void> rebuildCurrent({
    required PlaybackConfig config,
    required List<NarratorOption> narrators,
  }) async {
    if (_affirmationQueue.isEmpty) {
      return;
    }
    _config = config;
    _narrators = narrators;
    _sentenceStartIndex = _session.currentSentenceIndex;
    await _startNewRun();
  }

  Future<void> jumpToSentence(int index) async {
    if (_affirmationQueue.isEmpty || _currentRendered.isEmpty) {
      return;
    }
    _sentenceStartIndex = index.clamp(0, _currentRendered.length - 1);
    await _startNewRun();
  }

  Future<void> setSleepTimer(SleepTimerOption? option) async {
    _sleepTimer?.cancel();
    _stopAfterCurrentSentence = option?.stopAfterSentence ?? false;
    if (option?.duration != null) {
      final endsAt = DateTime.now().add(option!.duration!);
      _sleepTimer = Timer(option.duration!, () => stop());
      _setSession(_session.copyWith(sleepTimerEndsAt: endsAt));
    } else {
      _setSession(_session.copyWith(sleepTimerEndsAt: null));
    }
  }

  Future<void> updateMix({
    double? bgmVolume,
    double? voiceVolume,
    double? speechRate,
  }) async {
    _config = _config.copyWith(
      bgmVolume: bgmVolume,
      voiceVolume: voiceVolume,
      speechRate: speechRate,
    );
    await _bgmPlayer.setVolume(_config.bgmVolume);
    await _voicePlayer.setVolume(_config.voiceVolume);
    await _voicePlayer.setSpeed(_config.speechRate.clamp(0.5, 1.25));
    _setSession(
      _session.copyWith(
        bgmVolume: _config.bgmVolume,
        voiceVolume: _config.voiceVolume,
        speechRate: _config.speechRate,
      ),
    );
  }

  Future<void> updatePlaybackOptions({
    bool? shuffle,
    RepeatMode? repeatMode,
  }) async {
    _config = _config.copyWith(shuffle: shuffle, repeatMode: repeatMode);
    _setSession(
      _session.copyWith(
        shuffle: _config.shuffle,
        repeatMode: _config.repeatMode,
      ),
    );
  }

  @override
  Future<void> play() async {
    _paused = false;
    unawaited(_bgmPlayer.play());
    if (_voicePlayer.audioSource != null &&
        _voicePlayer.processingState != ProcessingState.completed) {
      unawaited(_voicePlayer.play());
    }
    _setSession(_session.copyWith(isPlaying: true));
    _broadcastPlaybackState();
  }

  @override
  Future<void> pause() async {
    _paused = true;
    await _voicePlayer.pause();
    await _bgmPlayer.pause();
    _setSession(_session.copyWith(isPlaying: false));
    _broadcastPlaybackState();
  }

  @override
  Future<void> stop() async {
    _playToken++;
    _sleepTimer?.cancel();
    _paused = false;
    _stopAfterCurrentSentence = false;
    await _voicePlayer.stop();
    await _bgmPlayer.stop();
    _setSession(_session.copyWith(isPlaying: false, sleepTimerEndsAt: null));
    _broadcastPlaybackState();
  }

  @override
  Future<void> seek(Duration position) async {
    if (_voicePlayer.audioSource != null) {
      await _voicePlayer.seek(position);
    }
  }

  @override
  Future<void> skipToNext() async {
    if (_affirmationQueue.isEmpty) {
      return;
    }
    _queueIndex = (_queueIndex + 1) % _affirmationQueue.length;
    _sentenceStartIndex = 0;
    await _startNewRun();
  }

  @override
  Future<void> skipToPrevious() async {
    if (_affirmationQueue.isEmpty) {
      return;
    }
    _queueIndex = _queueIndex == 0 ? _affirmationQueue.length - 1 : _queueIndex - 1;
    _sentenceStartIndex = 0;
    await _startNewRun();
  }

  Future<void> _startNewRun() async {
    await stop();
    _playToken++;
    final token = _playToken;
    unawaited(_runPlayback(token));
  }

  Future<void> _runPlayback(int token) async {
    if (_affirmationQueue.isEmpty) {
      return;
    }
    final affirmation = _affirmationQueue[_queueIndex];
    final narrator = _resolveNarrator();
    if (narrator == null) {
      _setSession(_session.copyWith(errorMessage: 'ナレーターが見つかりません。'));
      return;
    }

    _currentRendered = _playbackCoordinator.buildRenderedSentences(
      affirmation: affirmation,
      config: _config,
    );
    if (_currentRendered.isEmpty) {
      _setSession(_session.copyWith(errorMessage: '再生できる文がありません。'));
      return;
    }
    await _affirmationRepository.save(
      affirmation.copyWith(
        playCount: affirmation.playCount + 1,
        lastPlayedAt: DateTime.now(),
      ),
    );

    queue.add(
      _affirmationQueue
          .map(
            (item) => MediaItem(
              id: item.id,
              title: item.title,
              album: 'アファメーション',
            ),
          )
          .toList(),
    );

    _setSession(
      _session.copyWith(
        currentAffirmationId: affirmation.id,
        currentAffirmationTitle: affirmation.title,
        currentSentenceIndex: _sentenceStartIndex,
        totalSentenceCount: _currentRendered.length,
        isPlaying: true,
        currentRenderedText: _currentRendered[_sentenceStartIndex].renderedText,
        queueAffirmationIds: _affirmationQueue.map((item) => item.id).toList(),
        startedAt: DateTime.now(),
        mode: _config.mode,
        repeatMode: _config.repeatMode,
        shuffle: _config.shuffle,
        bgmName: _resolveBgm()?.displayName ?? '無音',
        narratorName: narrator.displayName,
        bgmVolume: _config.bgmVolume,
        voiceVolume: _config.voiceVolume,
        speechRate: _config.speechRate,
        currentSentencePosition: Duration.zero,
        currentSentenceDuration: Duration.zero,
        errorMessage: null,
      ),
    );

    mediaItem.add(
      MediaItem(
        id: affirmation.id,
        title: affirmation.title,
        album: '${narrator.displayName} / ${_resolveBgm()?.displayName ?? '無音'}',
      ),
    );

    Future<File> prepareSentence(int index) async {
      final sentence = _currentRendered[index];
      debugPrint(
        '[playback] synth start sentence=${index + 1}/${_currentRendered.length} text="${sentence.renderedText}"',
      );
      final file = await _synthesisPipeline.getOrCreateAudio(
        sentence: sentence,
        narrator: narrator,
        config: _config,
        availableNarrators: _narrators,
      );
      debugPrint(
        '[playback] synth done sentence=${index + 1}/${_currentRendered.length} path=${file.path}',
      );
      return file;
    }

    final firstSentenceFuture = prepareSentence(_sentenceStartIndex);

    await _startBgm();
    await _timedWait(Duration(milliseconds: _config.startDelayMs), token);

    for (var index = _sentenceStartIndex; index < _currentRendered.length; index++) {
      if (token != _playToken) {
        return;
      }
      final sentence = _currentRendered[index];
      _setSession(
        _session.copyWith(
          currentSentenceIndex: index,
          currentRenderedText: sentence.renderedText,
          currentSentencePosition: Duration.zero,
          currentSentenceDuration: Duration.zero,
        ),
      );

      try {
        final file = index == _sentenceStartIndex
            ? await firstSentenceFuture
            : await prepareSentence(index);
        await _playSentenceFile(file, token);
      } catch (error) {
        debugPrint(
          '[playback] sentence failed sentence=${index + 1}/${_currentRendered.length} error=$error',
        );
        _setSession(_session.copyWith(errorMessage: error.toString()));
      }

      if (token != _playToken) {
        return;
      }
      if (_stopAfterCurrentSentence) {
        await stop();
        return;
      }
      if (index < _currentRendered.length - 1) {
        await _timedWait(Duration(milliseconds: _config.sentenceGapMs), token);
      }
    }

    if (token != _playToken) {
      return;
    }
    await _handleCompletion();
  }

  Future<void> _handleCompletion() async {
    switch (_config.repeatMode) {
      case RepeatMode.one:
        _sentenceStartIndex = 0;
        await _startNewRun();
        break;
      case RepeatMode.all:
        _queueIndex = (_queueIndex + 1) % _affirmationQueue.length;
        _sentenceStartIndex = 0;
        await _startNewRun();
        break;
      case RepeatMode.none:
        if (_config.shuffle && _affirmationQueue.length > 1) {
          _affirmationQueue = [..._affirmationQueue]..shuffle();
          _queueIndex = 0;
          _sentenceStartIndex = 0;
          await _startNewRun();
        } else if (_queueIndex < _affirmationQueue.length - 1) {
          _queueIndex += 1;
          _sentenceStartIndex = 0;
          await _startNewRun();
        } else {
          await stop();
        }
    }
  }

  Future<void> _startBgm() async {
    final bgm = _resolveBgm();
    if (bgm == null) {
      await _bgmPlayer.stop();
      return;
    }
    await _bgmPlayer.setLoopMode(LoopMode.one);
    await _bgmPlayer.setAsset(bgm.assetPath);
    await _bgmPlayer.setVolume(_config.bgmVolume);
    unawaited(_bgmPlayer.play());
  }

  Future<void> _playSentenceFile(File file, int token) async {
    debugPrint('[playback] play start path=${file.path}');
    await _voicePlayer.stop();
    await _voicePlayer.setFilePath(file.path);
    await _voicePlayer.setVolume(_config.voiceVolume);
    await _voicePlayer.setSpeed(_config.speechRate.clamp(0.5, 1.25));
    await _voicePlayer.play();
    debugPrint('[playback] play completed path=${file.path}');
  }

  Future<void> _timedWait(Duration duration, int token) async {
    var remaining = duration;
    while (remaining > Duration.zero && token == _playToken) {
      if (_paused) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
        continue;
      }
      final slice = remaining > const Duration(milliseconds: 150)
          ? const Duration(milliseconds: 150)
          : remaining;
      await Future<void>.delayed(slice);
      remaining -= slice;
    }
  }

  NarratorOption? _resolveNarrator() {
    for (final narrator in _narrators) {
      if (narrator.id == _config.narratorId) {
        return narrator;
      }
    }
    return _narrators.isNotEmpty ? _narrators.first : null;
  }

  BgmTrack? _resolveBgm() {
    if (_config.bgmId == null) {
      return null;
    }
    for (final track in AppBgmCatalog.tracks) {
      if (track.id == _config.bgmId) {
        return track;
      }
    }
    return null;
  }

  void _setSession(PlaybackSessionState state) {
    _session = state;
    _sessionController.add(_session);
    _broadcastPlaybackState();
  }

  void _broadcastPlaybackState() {
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (_session.isPlaying) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        androidCompactActionIndices: const [0, 1, 3],
        processingState: _voicePlayer.processingState == ProcessingState.loading
            ? AudioProcessingState.loading
            : (_session.isPlaying
                ? AudioProcessingState.ready
                : AudioProcessingState.idle),
        playing: _session.isPlaying,
        updatePosition: _voicePlayer.position,
        bufferedPosition: _voicePlayer.bufferedPosition,
        speed: _config.speechRate,
        queueIndex: _queueIndex,
      ),
    );
  }

  @override
  Future<void> onTaskRemoved() async {
    await _bgmPlayer.stop();
    await _voicePlayer.stop();
    return super.onTaskRemoved();
  }

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) {
    return super.customAction(name, extras);
  }
}
