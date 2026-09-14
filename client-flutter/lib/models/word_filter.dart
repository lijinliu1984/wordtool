/// 单词筛选条件（level 和 category 可独立或组合使用）
class WordFilter {
  /// 数字等级（可选），如 3=初中、4=高中、5=四级
  final int? level;

  /// 分类ID（可选）
  final int? categoryId;

  const WordFilter({this.level, this.categoryId});

  /// 两者都未选
  bool get isEmpty => level == null && categoryId == null;

  /// 同时选择了 level 和 category
  bool get hasBoth => level != null && categoryId != null;

  /// 仅选了 level
  bool get hasLevelOnly => level != null && categoryId == null;

  /// 仅选了 category
  bool get hasCategoryOnly => level == null && categoryId != null;

  @override
  String toString() {
    if (isEmpty) return '全部单词';
    if (hasBoth) return '等级 $level + 分类';
    if (level != null) return '等级 $level';
    return '分类';
  }
}
