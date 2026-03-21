import 'package:uuid/uuid.dart';

class Affirmation {
  const Affirmation({
    required this.id,
    required this.title,
    this.note,
    required this.tags,
    required this.sentences,
    required this.isFavorite,
    required this.playCount,
    required this.lastPlayedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String? note;
  final List<String> tags;
  final List<AffirmationSentence> sentences;
  final bool isFavorite;
  final int playCount;
  final DateTime? lastPlayedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Affirmation copyWith({
    String? id,
    String? title,
    String? note,
    List<String>? tags,
    List<AffirmationSentence>? sentences,
    bool? isFavorite,
    int? playCount,
    DateTime? lastPlayedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Affirmation(
      id: id ?? this.id,
      title: title ?? this.title,
      note: note ?? this.note,
      tags: tags ?? this.tags,
      sentences: sentences ?? this.sentences,
      isFavorite: isFavorite ?? this.isFavorite,
      playCount: playCount ?? this.playCount,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Affirmation duplicate() {
    const uuid = Uuid();
    final now = DateTime.now();
    return Affirmation(
      id: uuid.v4(),
      title: '$title のコピー',
      note: note,
      tags: [...tags],
      sentences: [
        for (final sentence in sentences)
          sentence.copyWith(
            id: uuid.v4(),
          ),
      ],
      isFavorite: false,
      playCount: 0,
      lastPlayedAt: null,
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'note': note,
        'tags': tags,
        'sentences': sentences.map((item) => item.toJson()).toList(),
        'isFavorite': isFavorite,
        'playCount': playCount,
        'lastPlayedAt': lastPlayedAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Affirmation.fromJson(Map<String, dynamic> json) {
    return Affirmation(
      id: json['id'] as String,
      title: json['title'] as String? ?? '無題のアファメーション',
      note: json['note'] as String?,
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      sentences: (json['sentences'] as List<dynamic>? ?? const [])
          .map((item) => AffirmationSentence.fromJson(item as Map<String, dynamic>))
          .toList(),
      isFavorite: json['isFavorite'] as bool? ?? false,
      playCount: json['playCount'] as int? ?? 0,
      lastPlayedAt: json['lastPlayedAt'] == null
          ? null
          : DateTime.tryParse(json['lastPlayedAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class AffirmationSentence {
  const AffirmationSentence({
    required this.id,
    required this.order,
    required this.subjectText,
    required this.predicateText,
    this.useConfigFirstPerson = true,
  });

  final String id;
  final int order;
  final String subjectText;
  final String predicateText;
  final bool useConfigFirstPerson;

  AffirmationSentence copyWith({
    String? id,
    int? order,
    String? subjectText,
    String? predicateText,
    bool? useConfigFirstPerson,
  }) {
    return AffirmationSentence(
      id: id ?? this.id,
      order: order ?? this.order,
      subjectText: subjectText ?? this.subjectText,
      predicateText: predicateText ?? this.predicateText,
      useConfigFirstPerson: useConfigFirstPerson ?? this.useConfigFirstPerson,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'order': order,
        'subjectText': subjectText,
        'predicateText': predicateText,
        'useConfigFirstPerson': useConfigFirstPerson,
      };

  factory AffirmationSentence.fromJson(Map<String, dynamic> json) {
    return AffirmationSentence(
      id: json['id'] as String,
      order: json['order'] as int? ?? 0,
      subjectText: json['subjectText'] as String? ?? '',
      predicateText: json['predicateText'] as String? ?? '',
      useConfigFirstPerson: json['useConfigFirstPerson'] as bool? ?? true,
    );
  }
}
