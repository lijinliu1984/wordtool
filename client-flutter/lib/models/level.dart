/// 学段模型（对应服务端 word_level 表）
class Level {
  /// 数字等级（1-10），对应 words.level 字段
  final int level;

  /// 学段名称，如 "初中"、"高中"、"四级"
  final String name;

  /// 该学段的单词数量
  final int wordCount;

  Level({required this.level, required this.name, required this.wordCount});

  factory Level.fromMap(Map<String, dynamic> map) {
    return Level(
      level: map['level'] as int,
      name: map['name'] as String,
      wordCount: map['words_count'] as int? ?? 0,
    );
  }
}
