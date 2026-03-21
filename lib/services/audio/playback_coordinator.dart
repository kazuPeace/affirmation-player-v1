import 'package:crypto/crypto.dart';

import '../../models/affirmation.dart';
import '../../models/playback_config.dart';
import '../../models/rendered_sentence.dart';

class PlaybackCoordinator {
  List<RenderedSentence> buildRenderedSentences({
    required Affirmation affirmation,
    required PlaybackConfig config,
  }) {
    final ordered = [...affirmation.sentences]..sort((a, b) => a.order.compareTo(b.order));
    return [
      for (var i = 0; i < ordered.length; i++)
        RenderedSentence(
          sentenceId: ordered[i].id,
          index: i,
          sourceText: ordered[i].predicateText,
          renderedText: renderSentence(ordered[i], config),
          audioCacheKey: buildCacheKey(
            narratorId: config.narratorId,
            narratorType: config.narratorType,
            speechRate: config.speechRate,
            renderedText: renderSentence(ordered[i], config),
          ),
          resolvedNarratorId: config.narratorId,
        ),
    ];
  }

  String renderSentence(AffirmationSentence sentence, PlaybackConfig config) {
    final predicate = normalizePredicate(sentence.predicateText);
    if (config.mode == AffirmationMode.you) {
      return 'あなたは$predicate';
    }
    if (!sentence.useConfigFirstPerson) {
      return predicate;
    }
    final subject = config.defaultFirstPerson.trim().isNotEmpty
        ? config.defaultFirstPerson.trim()
        : '私';
    return '$subject$predicate';
  }

  String normalizePredicate(String raw) {
    final trimmed = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) {
      return '';
    }
    if (trimmed.endsWith('。') ||
        trimmed.endsWith('！') ||
        trimmed.endsWith('!') ||
        trimmed.endsWith('？') ||
        trimmed.endsWith('?')) {
      return trimmed;
    }
    return '$trimmed。';
  }

  String buildCacheKey({
    required String narratorId,
    required NarratorType narratorType,
    required double speechRate,
    required String renderedText,
  }) {
    final normalized = renderedText.trim().replaceAll(RegExp(r'\s+'), ' ');
    final payload =
        '${narratorType.name}|$narratorId|${speechRate.toStringAsFixed(2)}|$normalized';
    return sha1.convert(payload.codeUnits).toString();
  }
}
