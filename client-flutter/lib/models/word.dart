/// 单词模型（对应服务端 words 表）
///
/// 适配 ECDict 词库结构，包含音标、释义、词频等信息。
/// 提供兼容旧模型的 getter（learnWord/myWord/image 等），
/// 使现有练习页面无需大幅改动。
class Word {
  final int? id;

  /// 单词本身
  final String word;

  /// 音标（IPA 格式）
  final String? phonetic;

  /// 英文释义
  final String? definition;

  /// 中文释义
  final String? translation;

  /// 词性（如 n./v./adj.）
  final String? pos;

  /// 柯林斯星级（0-5，5 星最常用）
  final int collins;

  /// 牛津标注
  final int oxford;

  /// 原始考试标签（如 "zk gk cet4"）
  final String? tag;

  /// BNC 语料库词频排名（越小越常见）
  final int bnc;

  /// 当代语料库词频排名
  final int frq;

  /// 词形变化信息
  final String? exchange;

  /// 详细释义
  final String? detail;

  /// 图标/图片
  final String? pic;

  /// 音频链接
  final String? audio;

  /// 主要展示学段（最低适用学段）
  final String? primaryLevel;

  Word({
    this.id,
    required this.word,
    this.phonetic,
    this.definition,
    this.translation,
    this.pos,
    this.collins = 0,
    this.oxford = 0,
    this.tag,
    this.bnc = 0,
    this.frq = 0,
    this.exchange,
    this.detail,
    this.pic,
    this.audio,
    this.primaryLevel,
  });

  factory Word.fromMap(Map<String, dynamic> map) {
    return Word(
      id: map['id'] as int?,
      word: map['word'] as String? ?? '',
      phonetic: map['phonetic'] as String?,
      definition: map['definition'] as String?,
      translation: map['translation'] as String?,
      pos: map['pos'] as String?,
      collins: map['collins'] as int? ?? 0,
      oxford: map['oxford'] as int? ?? 0,
      tag: map['tag'] as String?,
      bnc: map['bnc'] as int? ?? 0,
      frq: map['frq'] as int? ?? 0,
      exchange: map['exchange'] as String?,
      detail: map['detail'] as String?,
      pic: map['pic'] as String?,
      audio: map['audio'] as String?,
      primaryLevel: map['primary_level'] as String?,
    );
  }

  // ==================== 兼容旧模型的 getter ====================
  // 以下 getter 使现有练习页面（TranslationPracticePage 等）无需大幅改动。

  /// 兼容旧模型：学习词（目标语言）
  String get learnWord => word;

  /// 兼容旧模型：母语词（中文翻译）
  String get myWord => translation ?? '';

  /// 兼容旧模型：图片
  String? get image => pic;

  /// 兼容旧模型：缩写/词性
  String? get abbreviation => pos;

  /// 兼容旧模型：描述（音标）
  String? get description => phonetic;

  Word copyWith({
    int? id,
    String? word,
    String? phonetic,
    String? definition,
    String? translation,
    String? pos,
    int? collins,
    int? oxford,
    String? tag,
    int? bnc,
    int? frq,
    String? exchange,
    String? detail,
    String? pic,
    String? audio,
    String? primaryLevel,
  }) {
    return Word(
      id: id ?? this.id,
      word: word ?? this.word,
      phonetic: phonetic ?? this.phonetic,
      definition: definition ?? this.definition,
      translation: translation ?? this.translation,
      pos: pos ?? this.pos,
      collins: collins ?? this.collins,
      oxford: oxford ?? this.oxford,
      tag: tag ?? this.tag,
      bnc: bnc ?? this.bnc,
      frq: frq ?? this.frq,
      exchange: exchange ?? this.exchange,
      detail: detail ?? this.detail,
      pic: pic ?? this.pic,
      audio: audio ?? this.audio,
      primaryLevel: primaryLevel ?? this.primaryLevel,
    );
  }
}
