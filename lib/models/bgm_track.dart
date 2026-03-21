class BgmTrack {
  const BgmTrack({
    required this.id,
    required this.assetPath,
    required this.displayName,
    this.durationMs,
  });

  final String id;
  final String assetPath;
  final String displayName;
  final int? durationMs;
}
