/// 分类模型（对应服务端 categories 表，单词数通过 words.categorie 统计）
class Category {
  /// 分类ID
  final int id;

  /// 英文分类名，如 "animal"
  final String name;

  /// 中文分类名，如 "动物"
  final String cnName;

  /// 分类描述
  final String? description;

  /// 分类图标/图片
  final String? pic;

  /// 分类名英文读音（TTS 朗读文本）
  final String? audio;

  /// 该分类的单词数量
  final int wordCount;

  Category({
    required this.id,
    required this.name,
    required this.cnName,
    this.description,
    this.pic,
    this.audio,
    required this.wordCount,
  });

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int,
      name: map['name'] as String,
      cnName: map['cn_name'] as String? ?? map['name'] as String,
      description: map['description'] as String?,
      pic: map['pic'] as String?,
      audio: map['audio'] as String?,
      wordCount: map['word_count'] as int? ?? 0,
    );
  }
}
