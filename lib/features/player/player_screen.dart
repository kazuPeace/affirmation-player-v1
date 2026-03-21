import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants.dart';
import '../../models/playback_config.dart' as playback_model;
import '../../models/playback_session_state.dart';

class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackSessionProvider).valueOrNull ??
        PlaybackSessionState.idle();
    final settings = ref.watch(settingsControllerProvider).valueOrNull;
    final handler = ref.read(audioHandlerProvider);
    final positionStream = AudioService.position;

    return Scaffold(
      appBar: AppBar(
        title: const Text('再生中'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          children: [
            Container(
              height: 280,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(34),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF6EE7D1), Color(0xFFFFC982), Color(0xFF213453)],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -10,
                    top: 20,
                    child: Icon(
                      Icons.music_note_rounded,
                      size: 160,
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  const Positioned(
                    left: 24,
                    bottom: 24,
                    child: Icon(Icons.graphic_eq, size: 64, color: Colors.black87),
                  ),
                  Positioned(
                    left: 24,
                    top: 24,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        playback.isPlaying ? 'PLAYING' : 'PAUSED',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text(
              playback.currentAffirmationTitle,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              '${playback.narratorName} / ${playback.bgmName} / ${playback.mode == playback_model.AffirmationMode.you ? 'YOU' : '通常'}',
              style: const TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF121926),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('文 ${playback.currentSentenceIndex + 1}/${playback.totalSentenceCount}'),
                      const Spacer(),
                      Text(
                        '${playback.currentSentencePosition.inSeconds}s / ${playback.currentSentenceDuration.inSeconds}s',
                        style: const TextStyle(color: Colors.white60),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: playback.totalSentenceCount == 0
                        ? 0
                        : (playback.currentSentenceIndex + 1) /
                            playback.totalSentenceCount,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<Duration>(
                    stream: positionStream,
                    builder: (context, snapshot) {
                      final position =
                          snapshot.data ?? playback.currentSentencePosition;
                      final max = playback.currentSentenceDuration.inMilliseconds
                                  .toDouble() ==
                              0
                          ? 1.0
                          : playback.currentSentenceDuration.inMilliseconds.toDouble();
                      final current = position.inMilliseconds
                          .clamp(0, max.toInt())
                          .toDouble();
                      return Slider(
                        value: current.toDouble(),
                        max: max,
                        onChanged: playback.currentSentenceDuration == Duration.zero
                            ? null
                            : (value) => handler.seek(
                                  Duration(milliseconds: value.round()),
                                ),
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  Text(
                    playback.currentRenderedText,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  onPressed: () => handler.updatePlaybackOptions(
                    shuffle: !playback.shuffle,
                  ),
                  icon: Icon(
                    Icons.shuffle,
                    color: playback.shuffle ? Theme.of(context).colorScheme.primary : null,
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: handler.skipToPrevious,
                  icon: const Icon(Icons.skip_previous),
                  iconSize: 34,
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(24),
                  ),
                  onPressed: playback.isPlaying ? handler.pause : handler.play,
                  child: Icon(
                    playback.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 36,
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: handler.skipToNext,
                  icon: const Icon(Icons.skip_next),
                  iconSize: 34,
                ),
                IconButton(
                  onPressed: () {
                    final next = switch (playback.repeatMode) {
                      playback_model.RepeatMode.none =>
                        playback_model.RepeatMode.one,
                      playback_model.RepeatMode.one =>
                        playback_model.RepeatMode.all,
                      playback_model.RepeatMode.all =>
                        playback_model.RepeatMode.none,
                    };
                    handler.updatePlaybackOptions(repeatMode: next);
                  },
                  icon: Icon(
                    playback.repeatMode == playback_model.RepeatMode.one
                        ? Icons.repeat_one
                        : Icons.repeat,
                    color: playback.repeatMode == playback_model.RepeatMode.none
                        ? null
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ActionChip(
                  label: const Text('スリープタイマー'),
                  avatar: const Icon(Icons.bedtime_outlined),
                  onPressed: () => _showSleepTimerSheet(context, handler),
                ),
                ActionChip(
                  label: const Text('キュー'),
                  avatar: const Icon(Icons.queue_music),
                  onPressed: () => _showQueueSheet(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF121926),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  _PlayerSlider(
                    label: 'BGM音量',
                    value: playback.bgmVolume,
                    max: 1,
                    onChanged: (value) => handler.updateMix(bgmVolume: value),
                  ),
                  _PlayerSlider(
                    label: 'ボイス音量',
                    value: playback.voiceVolume,
                    max: 1.2,
                    onChanged: (value) => handler.updateMix(voiceVolume: value),
                  ),
                  _PlayerSlider(
                    label: '再生速度',
                    value: playback.speechRate,
                    min: 0.5,
                    max: 1.25,
                    onChanged: (value) => handler.updateMix(speechRate: value),
                  ),
                ],
              ),
            ),
            if (playback.errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                playback.errorMessage!,
                style: const TextStyle(color: Colors.orangeAccent),
              ),
            ],
            if (settings != null) ...[
              const SizedBox(height: 14),
              FilledButton.tonalIcon(
                onPressed: () => handler.rebuildCurrent(
                  config: settings.config,
                  narrators: settings.narrators,
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('最新CONFIGで再生成'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showSleepTimerSheet(
    BuildContext context,
    dynamic handler,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text('スリープタイマー'),
            ),
            for (final option in SleepTimerOptions.items)
              ListTile(
                title: Text(option.label),
                onTap: () {
                  handler.setSleepTimer(option);
                  Navigator.of(context).pop();
                },
              ),
            ListTile(
              title: const Text('オフ'),
              onTap: () {
                handler.setSleepTimer(null);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showQueueSheet(BuildContext context, WidgetRef ref) async {
    final playback = ref.read(playbackSessionProvider).valueOrNull;
    if (playback == null) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: playback.totalSentenceCount,
            itemBuilder: (context, index) {
              final active = index == playback.currentSentenceIndex;
              return ListTile(
                tileColor: active ? const Color(0xFF203042) : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text(active ? playback.currentRenderedText : '文 ${index + 1}'),
                trailing: active ? const Icon(Icons.equalizer) : null,
                onTap: () {
                  ref.read(audioHandlerProvider).jumpToSentence(index);
                  Navigator.of(context).pop();
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PlayerSlider extends StatelessWidget {
  const _PlayerSlider({
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    required this.max,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text(label),
            const Spacer(),
            Text(value.toStringAsFixed(2)),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
