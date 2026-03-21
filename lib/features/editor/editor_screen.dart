import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/providers.dart';
import '../../models/affirmation.dart';

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key, this.affirmation});

  final Affirmation? affirmation;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  late final TextEditingController _tagsController;
  late List<_SentenceDraft> _sentences;
  var _dirty = false;

  @override
  void initState() {
    super.initState();
    final source = widget.affirmation;
    _titleController = TextEditingController(text: source?.title ?? '');
    _noteController = TextEditingController(text: source?.note ?? '');
    _tagsController = TextEditingController(text: source?.tags.join(', ') ?? '');
    _sentences = source?.sentences
            .map(
              (item) => _SentenceDraft(
                id: item.id,
                useConfigFirstPerson: item.useConfigFirstPerson,
                predicateController: TextEditingController(text: item.predicateText),
              ),
            )
            .toList() ??
        [
          _SentenceDraft(
            id: const Uuid().v4(),
            useConfigFirstPerson: true,
            predicateController: TextEditingController(),
          ),
        ];
    _listenDirty();
  }

  void _listenDirty() {
    for (final controller in [
      _titleController,
      _noteController,
      _tagsController,
      ..._sentences.map((item) => item.predicateController),
    ]) {
      controller.addListener(() {
        if (!_dirty) {
          setState(() => _dirty = true);
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    _tagsController.dispose();
    for (final sentence in _sentences) {
      sentence.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && await _confirmDiscard(context) && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.affirmation == null ? '新規アファメーション' : '編集'),
          actions: [
            TextButton(
              onPressed: _save,
              child: const Text('保存'),
            ),
          ],
        ),
        body: SafeArea(
          child: ReorderableListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) {
                  newIndex -= 1;
                }
                final item = _sentences.removeAt(oldIndex);
                _sentences.insert(newIndex, item);
                _dirty = true;
              });
            },
            children: [
              _SectionCard(
                key: const ValueKey('meta'),
                child: Column(
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'タイトル'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _noteController,
                      decoration: const InputDecoration(labelText: 'メモ'),
                      minLines: 2,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _tagsController,
                      decoration: const InputDecoration(
                        labelText: 'タグ',
                        hintText: '朝, 集中, 眠る前',
                      ),
                    ),
                  ],
                ),
              ),
              for (var index = 0; index < _sentences.length; index++)
                _SentenceCard(
                  key: ValueKey(_sentences[index].id),
                  index: index,
                  draft: _sentences[index],
                  onToggleUseConfigFirstPerson: (value) {
                    setState(() {
                      _sentences[index].useConfigFirstPerson = value;
                      _dirty = true;
                    });
                  },
                  onDelete: () {
                    setState(() {
                      _sentences[index].dispose();
                      _sentences.removeAt(index);
                      _dirty = true;
                    });
                  },
                  onPreview: () => _previewSingle(index),
                ),
              _SectionCard(
                key: const ValueKey('footer'),
                child: Column(
                  children: [
                    FilledButton.icon(
                      onPressed: _addSentence,
                      icon: const Icon(Icons.add),
                      label: const Text('文を追加'),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: _previewAll,
                      icon: const Icon(Icons.play_circle_outline),
                      label: const Text('全文プレビュー'),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _save,
                      child: const Text('完了'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addSentence() {
    setState(() {
        _sentences.add(
          _SentenceDraft(
            id: const Uuid().v4(),
            useConfigFirstPerson: true,
            predicateController: TextEditingController(),
          ),
        );
      _dirty = true;
    });
  }

  Future<void> _previewSingle(int index) async {
    final settings = ref.read(settingsControllerProvider).valueOrNull;
    if (settings == null) {
      return;
    }
    final temp = _buildAffirmation(singleIndex: index);
    if (temp == null) {
      _showError('後続文を入力してください。');
      return;
    }
    await ref.read(audioHandlerProvider).previewAffirmation(
          affirmation: temp,
          config: settings.config,
          narrators: settings.narrators,
        );
  }

  Future<void> _previewAll() async {
    final settings = ref.read(settingsControllerProvider).valueOrNull;
    if (settings == null) {
      return;
    }
    final temp = _buildAffirmation();
    if (temp == null) {
      _showError('空の文があります。保存またはプレビューできません。');
      return;
    }
    await ref.read(audioHandlerProvider).previewAffirmation(
          affirmation: temp,
          config: settings.config,
          narrators: settings.narrators,
        );
  }

  Future<void> _save() async {
    final affirmation = _buildAffirmation();
    if (affirmation == null) {
      _showError('後続文が空の行があります。');
      return;
    }
    await ref.read(libraryControllerProvider.notifier).save(affirmation);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Affirmation? _buildAffirmation({int? singleIndex}) {
    final selectedDrafts = singleIndex == null ? _sentences : [_sentences[singleIndex]];
    if (selectedDrafts.any((item) => item.predicateController.text.trim().isEmpty)) {
      return null;
    }
    final now = DateTime.now();
    final source = widget.affirmation;
    final title = _titleController.text.trim().isEmpty
        ? '無題のアファメーション ${now.month}/${now.day} ${now.hour}:${now.minute.toString().padLeft(2, '0')}'
        : _titleController.text.trim();
    return Affirmation(
      id: source?.id ?? const Uuid().v4(),
      title: title,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      tags: _tagsController.text
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(),
      sentences: [
        for (var i = 0; i < selectedDrafts.length; i++)
          AffirmationSentence(
            id: selectedDrafts[i].id,
            order: i,
            subjectText: '',
            predicateText: selectedDrafts[i].predicateController.text.trim(),
            useConfigFirstPerson: selectedDrafts[i].useConfigFirstPerson,
          ),
      ],
      isFavorite: source?.isFavorite ?? false,
      playCount: source?.playCount ?? 0,
      lastPlayedAt: source?.lastPlayedAt,
      createdAt: source?.createdAt ?? now,
      updatedAt: now,
    );
  }

  Future<bool> _confirmDiscard(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('未保存の変更があります'),
        content: const Text('保存せずに戻りますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('破棄'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _SentenceDraft {
  _SentenceDraft({
    required this.id,
    required this.useConfigFirstPerson,
    required this.predicateController,
  });

  final String id;
  bool useConfigFirstPerson;
  final TextEditingController predicateController;

  void dispose() {
    predicateController.dispose();
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111823),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: child,
    );
  }
}

class _SentenceCard extends StatelessWidget {
  const _SentenceCard({
    super.key,
    required this.index,
    required this.draft,
    required this.onToggleUseConfigFirstPerson,
    required this.onDelete,
    required this.onPreview,
  });

  final int index;
  final _SentenceDraft draft;
  final ValueChanged<bool> onToggleUseConfigFirstPerson;
  final VoidCallback onDelete;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                child: Text('${index + 1}'),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '文の編集',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: onPreview,
                icon: const Icon(Icons.headphones),
              ),
              const Icon(Icons.drag_handle),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF171F2D),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Text(
              '通常は CONFIG の一人称を使います',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          const SizedBox(height: 10),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: draft.useConfigFirstPerson,
            title: const Text('この文で一人称を付ける'),
            subtitle: Text(
              draft.useConfigFirstPerson
                  ? 'ON: CONFIG の一人称 + 後続文'
                  : 'OFF: 後続文だけを読み上げ',
            ),
            onChanged: onToggleUseConfigFirstPerson,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: draft.predicateController,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(labelText: '後続文'),
          ),
        ],
      ),
    );
  }
}
