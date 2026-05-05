class Folder {
  final String id;
  final String name;
  final String? parentId;
  final bool hasChild;
  final String? path;

  Folder({
    required this.id,
    required this.name,
    this.parentId,
    this.hasChild = false,
    this.path,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'parent_id': parentId,
      'has_child': hasChild ? 1 : 0,
      'path': path,
    };
  }

  factory Folder.fromMap(Map<String, dynamic> map) {
    return Folder(
      id: map['id'] as String,
      name: map['name'] as String,
      parentId: map['parent_id'] as String?,
      hasChild: (map['has_child'] as int) == 1,
      path: map['path'] as String?,
    );
  }

  Folder copyWith({
    String? id,
    String? name,
    String? parentId,
    bool? hasChild,
    String? path,
  }) {
    return Folder(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      hasChild: hasChild ?? this.hasChild,
      path: path ?? this.path,
    );
  }
}
