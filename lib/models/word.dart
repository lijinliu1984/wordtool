class Word {
  final int? id;
  final String foldId;
  final String? abbreviation;
  final String learnWord;
  final String myWord;
  final String? description;
  final String? audio;
  final String? image;
  final bool hasAudioFile;

  Word({
    this.id,
    required this.foldId,
    this.abbreviation,
    required this.learnWord,
    required this.myWord,
    this.description,
    this.audio,
    this.image,
    this.hasAudioFile = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fold_id': foldId,
      'abbreviation': abbreviation,
      'learn_word': learnWord,
      'my_word': myWord,
      'description': description,
      'audio': audio,
      'image': image,
    };
  }

  factory Word.fromMap(Map<String, dynamic> map) {
    return Word(
      id: map['id'] as int?,
      foldId: map['fold_id'] as String,
      abbreviation: map['abbreviation'] as String?,
      learnWord: map['learn_word'] as String,
      myWord: map['my_word'] as String,
      description: map['description'] as String?,
      audio: map['audio'] as String?,
      image: map['image'] as String?,
      hasAudioFile: false,
    );
  }

  Word copyWith({
    int? id,
    String? foldId,
    String? abbreviation,
    String? learnWord,
    String? myWord,
    String? description,
    String? audio,
    String? image,
    bool? hasAudioFile,
  }) {
    return Word(
      id: id ?? this.id,
      foldId: foldId ?? this.foldId,
      abbreviation: abbreviation ?? this.abbreviation,
      learnWord: learnWord ?? this.learnWord,
      myWord: myWord ?? this.myWord,
      description: description ?? this.description,
      audio: audio ?? this.audio,
      image: image ?? this.image,
      hasAudioFile: hasAudioFile ?? this.hasAudioFile,
    );
  }
}
