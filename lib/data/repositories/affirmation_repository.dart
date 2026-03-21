import 'dart:convert';
import 'dart:io';

import '../../models/affirmation.dart';

class JsonAffirmationRepository {
  JsonAffirmationRepository({required File storageFile}) : _storageFile = storageFile;

  final File _storageFile;

  Future<List<Affirmation>> fetchAll() async {
    if (!await _storageFile.exists()) {
      return [];
    }
    final raw = await _storageFile.readAsString();
    if (raw.trim().isEmpty) {
      return [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    final items = decoded
        .map((item) => Affirmation.fromJson(item as Map<String, dynamic>))
        .toList();
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  Future<Affirmation?> fetchById(String id) async {
    final all = await fetchAll();
    for (final item in all) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  Future<void> save(Affirmation affirmation) async {
    final all = await fetchAll();
    final index = all.indexWhere((item) => item.id == affirmation.id);
    final normalized = affirmation.copyWith(
      title: affirmation.title.trim().isEmpty
          ? '無題のアファメーション ${DateTime.now().toIso8601String().substring(0, 16)}'
          : affirmation.title.trim(),
      tags: affirmation.tags
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList(),
      sentences: affirmation.sentences
          .where((item) => item.predicateText.trim().isNotEmpty)
          .toList(),
      updatedAt: DateTime.now(),
    );
    if (index >= 0) {
      all[index] = normalized;
    } else {
      all.add(normalized);
    }
    await _writeAll(all);
  }

  Future<void> delete(String id) async {
    final all = await fetchAll();
    all.removeWhere((item) => item.id == id);
    await _writeAll(all);
  }

  Future<void> _writeAll(List<Affirmation> items) async {
    await _storageFile.parent.create(recursive: true);
    await _storageFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        items.map((item) => item.toJson()).toList(),
      ),
    );
  }
}
