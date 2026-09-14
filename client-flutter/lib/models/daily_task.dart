/// 每日任务状态枚举
enum DailyTaskStatus {
  pending,    // 待完成
  completed,  // 已完成
  overdue,    // 已逾期
}

/// 每日任务（对应 daily_tasks 表）
class DailyTask {
  final int? id;
  final int taskId;
  final DateTime date;
  final int targetCount;
  final int learnedCount;
  final DailyTaskStatus status;
  final DateTime createdAt;

  DailyTask({
    this.id,
    required this.taskId,
    required this.date,
    required this.targetCount,
    this.learnedCount = 0,
    this.status = DailyTaskStatus.pending,
    required this.createdAt,
  });

  /// 是否已完成
  bool get isCompleted => status == DailyTaskStatus.completed;

  /// 是否逾期
  bool get isOverdue => status == DailyTaskStatus.overdue;

  /// 进度 (0.0 - 1.0)
  double get progress {
    if (targetCount == 0) return 0;
    return (learnedCount / targetCount).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task_id': taskId,
      'date': date.millisecondsSinceEpoch,
      'target_count': targetCount,
      'learned_count': learnedCount,
      'status': status.index,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory DailyTask.fromMap(Map<String, dynamic> map) {
    return DailyTask(
      id: map['id'] as int?,
      taskId: map['task_id'] as int,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      targetCount: map['target_count'] as int,
      learnedCount: map['learned_count'] as int? ?? 0,
      status: DailyTaskStatus.values[map['status'] as int? ?? 0],
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  DailyTask copyWith({
    int? id,
    int? taskId,
    DateTime? date,
    int? targetCount,
    int? learnedCount,
    DailyTaskStatus? status,
    DateTime? createdAt,
  }) {
    return DailyTask(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      date: date ?? this.date,
      targetCount: targetCount ?? this.targetCount,
      learnedCount: learnedCount ?? this.learnedCount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
