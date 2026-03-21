import 'dart:async';
import 'dart:io';

import '../../models/narrator_option.dart';
import '../../models/playback_config.dart';
import '../../models/rendered_sentence.dart';
import '../audio/playback_coordinator.dart';
import 'tts_file_engine.dart';
import 'voicevox_local_engine.dart';

class SentenceSynthesisPipeline {
  SentenceSynthesisPipeline({
    required Directory cacheDirectory,
    required VoicevoxLocalEngine voicevoxEngine,
    required TtsFileEngine ttsEngine,
    required PlaybackCoordinator playbackCoordinator,
  })  : _cacheDirectory = cacheDirectory,
        _voicevoxEngine = voicevoxEngine,
        _ttsEngine = ttsEngine,
        _playbackCoordinator = playbackCoordinator;

  final Directory _cacheDirectory;
  final VoicevoxLocalEngine _voicevoxEngine;
  final TtsFileEngine _ttsEngine;
  final PlaybackCoordinator _playbackCoordinator;
  Future<void> _synthesisQueue = Future<void>.value();

  Future<File> getOrCreateAudio({
    required RenderedSentence sentence,
    required NarratorOption narrator,
    required PlaybackConfig config,
    required List<NarratorOption> availableNarrators,
  }) async {
    await _cacheDirectory.create(recursive: true);
    final cacheFile = File('${_cacheDirectory.path}/${sentence.audioCacheKey}.wav');
    if (await cacheFile.exists()) {
      await cacheFile.setLastModified(DateTime.now());
      return cacheFile;
    }

    try {
      final result = await _enqueueSynthesis(
        () => _synthesize(
          sentence: sentence,
          narrator: narrator,
          config: config,
          outputPath: cacheFile.path,
        ),
      ).timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          throw Exception('音声生成がタイムアウトしました: ${sentence.renderedText}');
        },
      );
      await _trimCacheIfNeeded();
      return result;
    } catch (error) {
      if (narrator.type == NarratorType.voicevox) {
        final fallback = availableNarrators.cast<NarratorOption?>().firstWhere(
              (item) => item?.type == NarratorType.tts,
              orElse: () => null,
            );
        if (fallback != null) {
          return _synthesize(
            sentence: sentence.copyWith(
              audioCacheKey: _playbackCoordinator.buildCacheKey(
                narratorId: fallback.id,
                narratorType: fallback.type,
                speechRate: config.speechRate,
                renderedText: sentence.renderedText,
              ),
            ),
            narrator: fallback,
            config: config,
            outputPath:
                '${_cacheDirectory.path}/${_playbackCoordinator.buildCacheKey(narratorId: fallback.id, narratorType: fallback.type, speechRate: config.speechRate, renderedText: sentence.renderedText)}.wav',
          );
        }
      }
      rethrow;
    }
  }

  Future<File> _synthesize({
    required RenderedSentence sentence,
    required NarratorOption narrator,
    required PlaybackConfig config,
    required String outputPath,
  }) {
    switch (narrator.type) {
      case NarratorType.voicevox:
        return _voicevoxEngine.synthesizeSentence(
          text: sentence.renderedText,
          narrator: narrator,
          speechRate: config.speechRate,
          outputPath: outputPath,
        );
      case NarratorType.tts:
        return _ttsEngine.synthesizeSentence(
          text: sentence.renderedText,
          narrator: narrator,
          speechRate: config.speechRate,
          outputPath: outputPath,
        );
    }
  }

  Future<T> _enqueueSynthesis<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _synthesisQueue = _synthesisQueue.catchError((_) {}).then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<void> clearCache() async {
    if (await _cacheDirectory.exists()) {
      await _cacheDirectory.delete(recursive: true);
    }
  }

  Future<void> _trimCacheIfNeeded() async {
    final entries = await _cacheDirectory.list().where((item) => item is File).cast<File>().toList();
    var totalSize = 0;
    final withStats = <MapEntry<File, FileStat>>[];
    for (final file in entries) {
      final stat = await file.stat();
      totalSize += stat.size;
      withStats.add(MapEntry(file, stat));
    }

    const maxBytes = 120 * 1024 * 1024;
    if (totalSize <= maxBytes) {
      return;
    }

    withStats.sort((a, b) => a.value.modified.compareTo(b.value.modified));
    for (final entry in withStats) {
      if (totalSize <= maxBytes) {
        break;
      }
      totalSize -= entry.value.size;
      await entry.key.delete();
    }
  }
}

extension on RenderedSentence {
  RenderedSentence copyWith({
    String? sentenceId,
    int? index,
    String? sourceText,
    String? renderedText,
    String? audioCacheKey,
    String? resolvedNarratorId,
  }) {
    return RenderedSentence(
      sentenceId: sentenceId ?? this.sentenceId,
      index: index ?? this.index,
      sourceText: sourceText ?? this.sourceText,
      renderedText: renderedText ?? this.renderedText,
      audioCacheKey: audioCacheKey ?? this.audioCacheKey,
      resolvedNarratorId: resolvedNarratorId ?? this.resolvedNarratorId,
    );
  }
}
