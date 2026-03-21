import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../models/affirmation.dart';
import '../../models/narrator_option.dart';
import '../../models/playback_config.dart';
import '../editor/editor_screen.dart';
import '../player/player_screen.dart';
import '../settings/settings_screen.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryAsync = ref.watch(libraryControllerProvider);
    final filteredLibrary = ref.watch(filteredLibraryProvider);
    final settingsAsync = ref.watch(settingsControllerProvider);
    final playbackAsync = ref.watch(playbackSessionProvider);
    final isConfigExpanded = ref.watch(configExpandedProvider);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF121825),
              Color(0xFF090C13),
              Color(0xFF06080D),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Affirmation Player',
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '音楽プレーヤー感覚で、選んで、整えて、流す。',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.white70,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        IconButton.filledTonal(
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const SettingsScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.settings_outlined),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      onChanged: (value) =>
                          ref.read(librarySearchProvider.notifier).state = value,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'タイトルやタグで検索',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ChoiceChip(
                          label: const Text('更新順'),
                          selected: ref.watch(librarySortProvider) == LibrarySort.updatedAt,
                          onSelected: (_) => ref.read(librarySortProvider.notifier).state =
                              LibrarySort.updatedAt,
                        ),
                        ChoiceChip(
                          label: const Text('タイトル順'),
                          selected: ref.watch(librarySortProvider) == LibrarySort.title,
                          onSelected: (_) => ref.read(librarySortProvider.notifier).state =
                              LibrarySort.title,
                        ),
                        ChoiceChip(
                          label: const Text('再生回数順'),
                          selected: ref.watch(librarySortProvider) == LibrarySort.playCount,
                          onSelected: (_) => ref.read(librarySortProvider.notifier).state =
                              LibrarySort.playCount,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: libraryAsync.when(
                  data: (_) {
                    if (filteredLibrary.isEmpty) {
                      return const Center(
                        child: Text('アファメーションがありません。右下の + から作成できます。'),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      itemBuilder: (context, index) {
                        final affirmation = filteredLibrary[index];
                        final config = settingsAsync.valueOrNull?.config ??
                            PlaybackConfig.defaults();
                        final narrators =
                            settingsAsync.valueOrNull?.narrators ?? const <NarratorOption>[];
                        return _AffirmationTile(
                          affirmation: affirmation,
                          onPlay: () => _play(
                            context,
                            ref,
                            filteredLibrary,
                            index,
                            config,
                            narrators,
                          ),
                          onEdit: () => _openEditor(context, ref, affirmation),
                          onFavorite: () => ref
                              .read(libraryControllerProvider.notifier)
                              .toggleFavorite(affirmation),
                          onDuplicate: () => ref
                              .read(libraryControllerProvider.notifier)
                              .duplicate(affirmation),
                          onDelete: () => ref
                              .read(libraryControllerProvider.notifier)
                              .delete(affirmation.id),
                        );
                      },
                      separatorBuilder: (_, index) => const SizedBox(height: 12),
                      itemCount: filteredLibrary.length,
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(child: Text(error.toString())),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('新規作成'),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.62,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                playbackAsync.valueOrNull?.currentAffirmationId == null
                    ? const SizedBox.shrink()
                    : _MiniPlayer(
                        onOpenPlayer: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const PlayerScreen(),
                            ),
                          );
                        },
                      ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111823),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: settingsAsync.when(
                    data: (settings) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => ref.read(configExpandedProvider.notifier).state =
                              !isConfigExpanded,
                          child: Row(
                            children: [
                              const Icon(Icons.tune),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'CONFIG',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  settings.voicevoxStatus,
                                  textAlign: TextAlign.end,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white60,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(isConfigExpanded
                                  ? Icons.keyboard_arrow_down
                                  : Icons.keyboard_arrow_up),
                            ],
                          ),
                        ),
                        if (isConfigExpanded) ...[
                          const SizedBox(height: 16),
                          _ConfigPanel(settings: settings),
                        ],
                      ],
                    ),
                    loading: () => const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(),
                    ),
                    error: (error, _) => Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(error.toString()),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    Affirmation? affirmation,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EditorScreen(affirmation: affirmation),
      ),
    );
    await ref.read(libraryControllerProvider.notifier).refresh();
  }

  Future<void> _play(
    BuildContext context,
    WidgetRef ref,
    List<Affirmation> queue,
    int index,
    PlaybackConfig config,
    List<NarratorOption> narrators,
  ) async {
    await ref.read(audioHandlerProvider).startPlayback(
          libraryQueue: queue,
          startIndex: index,
          config: config,
          narrators: narrators,
        );
    if (context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const PlayerScreen(),
        ),
      );
    }
  }
}

class _AffirmationTile extends StatelessWidget {
  const _AffirmationTile({
    required this.affirmation,
    required this.onPlay,
    required this.onEdit,
    required this.onFavorite,
    required this.onDuplicate,
    required this.onDelete,
  });

  final Affirmation affirmation;
  final VoidCallback onPlay;
  final VoidCallback onEdit;
  final VoidCallback onFavorite;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('yyyy/MM/dd').format(affirmation.updatedAt);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPlay,
        borderRadius: BorderRadius.circular(26),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(
              colors: [Color(0xFF182132), Color(0xFF10151F)],
            ),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF69E2C4), Color(0xFF2A5267)],
                  ),
                ),
                child: const Icon(Icons.graphic_eq, size: 34, color: Colors.black87),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      affirmation.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${affirmation.sentences.length}文 ・ 最終更新 $dateText ・ 再生 ${affirmation.playCount}回',
                      style: const TextStyle(color: Colors.white60),
                    ),
                    if (affirmation.tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final tag in affirmation.tags.take(3))
                            Chip(
                              label: Text(tag),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit();
                      break;
                    case 'duplicate':
                      onDuplicate();
                      break;
                    case 'favorite':
                      onFavorite();
                      break;
                    case 'delete':
                      onDelete();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('編集')),
                  const PopupMenuItem(value: 'duplicate', child: Text('複製')),
                  PopupMenuItem(
                    value: 'favorite',
                    child: Text(affirmation.isFavorite ? 'お気に入り解除' : 'お気に入り'),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('削除')),
                ],
              ),
              IconButton.filled(
                onPressed: onPlay,
                icon: const Icon(Icons.play_arrow),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfigPanel extends ConsumerStatefulWidget {
  const _ConfigPanel({required this.settings});

  final AppSettingsState settings;

  @override
  ConsumerState<_ConfigPanel> createState() => _ConfigPanelState();
}

class _ConfigPanelState extends ConsumerState<_ConfigPanel> {
  late final TextEditingController _firstPersonController;

  @override
  void initState() {
    super.initState();
    _firstPersonController = TextEditingController(
      text: widget.settings.config.defaultFirstPerson,
    );
  }

  @override
  void didUpdateWidget(covariant _ConfigPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextValue = widget.settings.config.defaultFirstPerson;
    if (_firstPersonController.text != nextValue) {
      _firstPersonController.value = TextEditingValue(
        text: nextValue,
        selection: TextSelection.collapsed(offset: nextValue.length),
      );
    }
  }

  @override
  void dispose() {
    _firstPersonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final config = settings.config;
    final currentPlayback = ref.watch(playbackSessionProvider).valueOrNull;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.52,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<AffirmationMode>(
              segments: const [
                ButtonSegment(value: AffirmationMode.you, label: Text('YOU')),
                ButtonSegment(value: AffirmationMode.normal, label: Text('通常')),
              ],
              selected: {config.mode},
              onSelectionChanged: (value) {
                ref.read(settingsControllerProvider.notifier).updateConfig(
                      config.copyWith(mode: value.first),
                    );
              },
            ),
            const SizedBox(height: 12),
            TextField(
              enabled: config.mode == AffirmationMode.normal,
              controller: _firstPersonController,
              onChanged: (value) {
                ref.read(settingsControllerProvider.notifier).updateConfig(
                      config.copyWith(defaultFirstPerson: value.isEmpty ? '私' : value),
                    );
              },
              decoration: const InputDecoration(
                labelText: '通常モードの一人称',
                hintText: '私',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: config.narratorId,
              decoration: const InputDecoration(labelText: 'ナレーター'),
              items: settings.narrators
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.id,
                      child: Text(item.displayName),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                final selected = settings.narrators.firstWhere((item) => item.id == value);
                ref.read(settingsControllerProvider.notifier).updateConfig(
                      config.copyWith(
                        narratorId: selected.id,
                        narratorType: selected.type,
                      ),
                    );
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: config.bgmId,
              decoration: const InputDecoration(labelText: 'BGM'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('BGMなし')),
                ...settings.bgmTracks.map(
                  (item) => DropdownMenuItem<String?>(
                    value: item.id,
                    child: Text(item.displayName),
                  ),
                ),
              ],
              onChanged: (value) {
                ref.read(settingsControllerProvider.notifier).updateConfig(
                      config.copyWith(bgmId: value),
                    );
              },
            ),
            const SizedBox(height: 8),
            _LabeledSlider(
              label: 'BGM音量',
              value: config.bgmVolume,
              min: 0,
              max: 1,
              onChanged: (value) =>
                  ref.read(settingsControllerProvider.notifier).updateConfig(
                        config.copyWith(bgmVolume: value),
                      ),
            ),
            _LabeledSlider(
              label: 'ボイス音量',
              value: config.voiceVolume,
              min: 0,
              max: 1.2,
              onChanged: (value) =>
                  ref.read(settingsControllerProvider.notifier).updateConfig(
                        config.copyWith(voiceVolume: value),
                      ),
            ),
            _LabeledSlider(
              label: '文間隔 (${(config.sentenceGapMs / 1000).toStringAsFixed(1)}秒)',
              value: config.sentenceGapMs.toDouble(),
              min: 0,
              max: 4000,
              onChanged: (value) =>
                  ref.read(settingsControllerProvider.notifier).updateConfig(
                        config.copyWith(sentenceGapMs: value.round()),
                      ),
            ),
            _LabeledSlider(
              label: '開始ディレイ (${(config.startDelayMs / 1000).toStringAsFixed(1)}秒)',
              value: config.startDelayMs.toDouble(),
              min: 0,
              max: 8000,
              onChanged: (value) =>
                  ref.read(settingsControllerProvider.notifier).updateConfig(
                        config.copyWith(startDelayMs: value.round()),
                      ),
            ),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () => _showPresetDialog(context, ref, settings),
                    child: const Text('プリセット保存'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: settings.presets.isEmpty
                      ? const SizedBox.shrink()
                      : DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: 'プリセット読込'),
                          items: settings.presets
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item.name,
                                  child: Text(item.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            final preset =
                                settings.presets.firstWhere((item) => item.name == value);
                            ref.read(settingsControllerProvider.notifier).applyPreset(preset);
                          },
                        ),
                ),
              ],
            ),
            if (currentPlayback?.currentAffirmationId != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  ref.read(audioHandlerProvider).rebuildCurrent(
                        config: settings.config,
                        narrators: settings.narrators,
                      );
                },
                icon: const Icon(Icons.refresh),
                label: const Text('今の再生へ反映'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showPresetDialog(
    BuildContext context,
    WidgetRef ref,
    AppSettingsState settings,
  ) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('プリセット保存'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: '名前'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () async {
              await ref.read(settingsControllerProvider.notifier).savePreset(
                    controller.text,
                  );
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
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

class _MiniPlayer extends ConsumerWidget {
  const _MiniPlayer({required this.onOpenPlayer});

  final VoidCallback onOpenPlayer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackSessionProvider).valueOrNull;
    if (playback == null || playback.currentAffirmationId == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onOpenPlayer,
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF161E2B),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFC982), Color(0xFF69E2C4)],
                    ),
                  ),
                  child: const Icon(Icons.multitrack_audio, color: Colors.black),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playback.currentAffirmationTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        playback.currentRenderedText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white60),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: ref.read(audioHandlerProvider).skipToPrevious,
                  icon: const Icon(Icons.skip_previous),
                ),
                IconButton.filled(
                  onPressed: playback.isPlaying
                      ? ref.read(audioHandlerProvider).pause
                      : ref.read(audioHandlerProvider).play,
                  icon: Icon(playback.isPlaying ? Icons.pause : Icons.play_arrow),
                ),
                IconButton(
                  onPressed: ref.read(audioHandlerProvider).skipToNext,
                  icon: const Icon(Icons.skip_next),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
