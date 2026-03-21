import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../../models/narrator_option.dart';
import '../../models/playback_config.dart';

class VoicevoxLocalEngine {
  static const MethodChannel _channel =
      MethodChannel('affirmation_player/voicevox');

  bool _initialized = false;
  List<NarratorOption> _cachedNarrators = const [];

  Future<List<NarratorOption>> fetchNarrators() async {
    if (!Platform.isAndroid) {
      return [];
    }
    await _ensureInitialized();
    return _cachedNarrators;
  }

  Future<File> synthesizeSentence({
    required String text,
    required NarratorOption narrator,
    required double speechRate,
    required String outputPath,
  }) async {
    if (!Platform.isAndroid) {
      throw Exception('VOICEVOX は現在 Android ローカル実装のみ対応です。');
    }
    await _ensureInitialized();
    final bytes = await _channel.invokeMethod<Uint8List>('synthesize', {
      'text': text,
      'styleId': narrator.voicevoxStyleId,
      'speechRate': speechRate,
    });
    if (bytes == null || bytes.isEmpty) {
      throw Exception('VOICEVOX の音声生成結果が空でした。');
    }
    final file = File(outputPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) {
      return;
    }
    try {
      final metasJson = await _channel.invokeMethod<String>('initialize');
      _cachedNarrators = _parseNarrators(metasJson ?? '[]');
      _initialized = true;
    } on PlatformException catch (error) {
      throw Exception('VOICEVOX 初期化失敗: ${error.message ?? error.code}');
    }
  }

  List<NarratorOption> _parseNarrators(String metasJson) {
    final decoded = jsonDecode(metasJson) as List<dynamic>;
    return [
      for (final speaker in decoded.cast<Map<String, dynamic>>())
        for (final style in (speaker['styles'] as List<dynamic>? ?? const []))
          NarratorOption(
            id: 'voicevox:${style['id']}',
            displayName:
                '${speaker['name']} / ${(style as Map<String, dynamic>)['name']}',
            type: NarratorType.voicevox,
            metadata: {
              'styleId': style['id'],
              'speakerName': speaker['name'],
              'styleName': style['name'],
            },
          ),
    ];
  }
}
