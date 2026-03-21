import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final documentsDir = ref.watch(documentsDirectoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: settings.when(
        data: (state) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SwitchListTile(
              value: state.config.headphoneAutoPause,
              onChanged: (value) => ref
                  .read(settingsControllerProvider.notifier)
                  .updateConfig(state.config.copyWith(headphoneAutoPause: value)),
              title: const Text('ヘッドホン抜去時に一時停止'),
            ),
            ListTile(
              title: const Text('VOICEVOX 接続状態'),
              subtitle: Text(state.voicevoxStatus),
              trailing: FilledButton.tonal(
                onPressed: () => ref.read(settingsControllerProvider.notifier).refreshNarrators(),
                child: const Text('再確認'),
              ),
            ),
            ListTile(
              title: const Text('音声キャッシュ削除'),
              subtitle: Text('保存先: ${documentsDir.path}/audio_cache'),
              trailing: FilledButton.tonal(
                onPressed: () async {
                  await ref.read(settingsControllerProvider.notifier).clearAudioCache();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('音声キャッシュを削除しました。')),
                    );
                  }
                },
                child: const Text('削除'),
              ),
            ),
            ListTile(
              title: const Text('データ保存先'),
              subtitle: Text(documentsDir.path),
            ),
            ListTile(
              title: const Text('プラットフォーム'),
              subtitle: Text(Platform.operatingSystem),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
      ),
    );
  }
}
