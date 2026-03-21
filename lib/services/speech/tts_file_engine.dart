import 'dart:io';

import 'package:flutter_tts/flutter_tts.dart';

import '../../models/narrator_option.dart';
import '../../models/playback_config.dart';

class TtsFileEngine {
  final FlutterTts _flutterTts = FlutterTts();

  Future<List<NarratorOption>> fetchNarrators() async {
    final voices = await _flutterTts.getVoices;
    if (voices is! List) {
      return const [
        NarratorOption(
          id: 'tts:default',
          displayName: '端末TTS',
          type: NarratorType.tts,
        ),
      ];
    }
    final narrators = voices
        .map((item) => item as Map<dynamic, dynamic>)
        .map(
          (item) => NarratorOption(
            id: 'tts:${item['name'] ?? 'default'}:${item['locale'] ?? 'default'}',
            displayName:
                '${item['name'] ?? '端末TTS'} (${item['locale'] ?? 'default'})',
            type: NarratorType.tts,
            metadata: {
              'name': item['name'],
              'locale': item['locale'],
            },
          ),
        )
        .toList();
    if (narrators.isEmpty) {
      return const [
        NarratorOption(
          id: 'tts:default',
          displayName: '端末TTS',
          type: NarratorType.tts,
        ),
      ];
    }
    return narrators;
  }

  Future<File> synthesizeSentence({
    required String text,
    required NarratorOption narrator,
    required double speechRate,
    required String outputPath,
  }) async {
    await _flutterTts.awaitSynthCompletion(true);
    await _flutterTts.setSpeechRate(speechRate.clamp(0.3, 0.9));

    if (narrator.ttsLocale != null) {
      await _flutterTts.setLanguage(narrator.ttsLocale!);
    }
    if (narrator.ttsName != null && narrator.ttsLocale != null) {
      await _flutterTts.setVoice({
        'name': narrator.ttsName!,
        'locale': narrator.ttsLocale!,
      });
    }

    final file = File(outputPath);
    await file.parent.create(recursive: true);
    if (await file.exists()) {
      await file.delete();
    }
    await _flutterTts.synthesizeToFile(text, file.path, true);

    final stopwatch = Stopwatch()..start();
    while (!await file.exists()) {
      if (stopwatch.elapsed > const Duration(seconds: 8)) {
        throw Exception('通常TTS の音声ファイル生成がタイムアウトしました。');
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    return file;
  }
}
