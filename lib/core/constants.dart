import '../models/bgm_track.dart';
import '../models/playback_config.dart';

class AppBgmCatalog {
  static const tracks = <BgmTrack>[
    BgmTrack(
      id: 'bgm_calm_pad',
      assetPath: 'assets/bgm/calm_pad.wav',
      displayName: 'Calm Pad',
      durationMs: 30000,
    ),
    BgmTrack(
      id: 'bgm_soft_bells',
      assetPath: 'assets/bgm/soft_bells.wav',
      displayName: 'Soft Bells',
      durationMs: 30000,
    ),
    BgmTrack(
      id: 'bgm_night_drift',
      assetPath: 'assets/bgm/night_drift.wav',
      displayName: 'Night Drift',
      durationMs: 30000,
    ),
  ];
}

class SleepTimerOption {
  const SleepTimerOption(this.label, this.duration, {this.stopAfterSentence = false});

  final String label;
  final Duration? duration;
  final bool stopAfterSentence;
}

class SleepTimerOptions {
  static const items = <SleepTimerOption>[
    SleepTimerOption('5分', Duration(minutes: 5)),
    SleepTimerOption('10分', Duration(minutes: 10)),
    SleepTimerOption('15分', Duration(minutes: 15)),
    SleepTimerOption('30分', Duration(minutes: 30)),
    SleepTimerOption('60分', Duration(minutes: 60)),
    SleepTimerOption('現在文で停止', null, stopAfterSentence: true),
  ];
}

const repeatModeLabels = <RepeatMode, String>{
  RepeatMode.none: 'オフ',
  RepeatMode.one: '1曲',
  RepeatMode.all: 'すべて',
};
