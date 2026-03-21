class RenderedSentence {
  const RenderedSentence({
    required this.sentenceId,
    required this.index,
    required this.sourceText,
    required this.renderedText,
    required this.audioCacheKey,
    required this.resolvedNarratorId,
  });

  final String sentenceId;
  final int index;
  final String sourceText;
  final String renderedText;
  final String audioCacheKey;
  final String resolvedNarratorId;
}
