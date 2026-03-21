import 'playback_config.dart';

class NarratorOption {
  const NarratorOption({
    required this.id,
    required this.displayName,
    required this.type,
    this.metadata = const {},
  });

  final String id;
  final String displayName;
  final NarratorType type;
  final Map<String, dynamic> metadata;

  int? get voicevoxStyleId => metadata['styleId'] as int?;
  String? get ttsName => metadata['name'] as String?;
  String? get ttsLocale => metadata['locale'] as String?;
}
