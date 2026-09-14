/// 任务状态枚举
enum TaskStatus {
  active,    // 进行中
  completed, // 已完成
  abandoned, // 已放弃
}

/// 学习任务
class Task {
  final int? id;
  final String name;
  final int? level;
  final int? categoryId;
  final int totalWords;
  final int dailyGoal;
  final DateTime startDate;
  final DateTime deadline;
  final TaskStatus status;
  final int? stars;
  final DateTime? completedAt;
  final DateTime createdAt;

  const Task({
    this.id,
    required this.name,
    this.level,
    this.categoryId,
    required this.totalWords,
    required this.dailyGoal,
    required this.startDate,
    required this.deadline,
    this.status = TaskStatus.active,
    this.stars,
    this.completedAt,
    required this.createdAt,
  });

  /// 是否进行中
  bool get isActive => status == TaskStatus.active;

  /// 是否已完成
  bool get isCompleted => status == TaskStatus.completed;

  /// 总天数（含截止日）
  int get totalDays => deadline.difference(startDate).inDays + 1;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'level': level,
      'category_id': categoryId,
      'total_words': totalWords,
      'daily_goal': dailyGoal,
      'start_date': startDate.millisecondsSinceEpoch,
      'deadline': deadline.millisecondsSinceEpoch,
      'status': status.index,
      'stars': stars,
      'completed_at': completedAt?.millisecondsSinceEpoch,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as int?,
      name: map['name'] as String,
      level: map['level'] as int?,
      categoryId: map['category_id'] as int?,
      totalWords: map['total_words'] as int,
      dailyGoal: map['daily_goal'] as int,
      startDate: DateTime.fromMillisecondsSinceEpoch(map['start_date'] as int),
      deadline: DateTime.fromMillisecondsSinceEpoch(map['deadline'] as int),
      status: TaskStatus.values[map['status'] as int? ?? 0],
      stars: map['stars'] as int?,
      completedAt: map['completed_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completed_at'] as int)
          : null,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  Task copyWith({
    int? id,
    String? name,
    int? level,
    int? categoryId,
    int? totalWords,
    int? dailyGoal,
    DateTime? startDate,
    DateTime? deadline,
    TaskStatus? status,
    int? stars,
    DateTime? completedAt,
    DateTime? createdAt,
  }) {
    return Task(
      id: id ?? this.id,
      name: name ?? this.name,
      level: level ?? this.level,
      categoryId: categoryId ?? this.categoryId,
      totalWords: totalWords ?? this.totalWords,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      startDate: startDate ?? this.startDate,
      deadline: deadline ?? this.deadline,
      status: status ?? this.status,
      stars: stars ?? this.stars,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
