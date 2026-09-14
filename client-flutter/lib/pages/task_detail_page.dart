import 'package:flutter/material.dart';

import '../db/user_database.dart';
import '../models/daily_task.dart';
import '../models/task.dart';
import 'task_edit_page.dart';

/// 任务详情页
class TaskDetailPage extends StatefulWidget {
  final Task task;

  const TaskDetailPage({super.key, required this.task});

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  List<DailyTask> _dailyTasks = [];
  int _totalLearned = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      _dailyTasks = await UserDatabase.instance.getDailyTasks(widget.task.id!);
      _totalLearned = await UserDatabase.instance.getTaskLearnedWordCount(widget.task);
    } catch (e) {
      debugPrint('任务详情加载失败: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _abandonTask() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('放弃任务'),
        content: const Text('确定要放弃此任务吗？放弃后将根据当前进度评分。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await UserDatabase.instance.abandonTask(widget.task.id!);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _editTask() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TaskEditPage(task: widget.task)),
    );
    if (result == true && mounted) Navigator.pop(context, true);
  }

  String _levelLabel() {
    if (widget.task.level != null) {
      return 'Level ${widget.task.level}';
    }
    if (widget.task.categoryId != null) {
      return '分类 ${widget.task.categoryId}';
    }
    return '全部单词';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.task.name, overflow: TextOverflow.ellipsis),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoCard(),
                  const SizedBox(height: 16),
                  if (widget.task.status != TaskStatus.active)
                    _buildScoreCard(),
                  if (widget.task.status != TaskStatus.active)
                    const SizedBox(height: 16),
                  _buildDailyTasksList(),
                  const SizedBox(height: 24),
                  if (widget.task.isActive) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _editTask,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('编辑任务'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _abandonTask,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('放弃任务'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard() {
    final task = widget.task;
    final progress = task.totalWords == 0
        ? 0.0
        : (_totalLearned / task.totalWords).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('任务概览', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: task.isActive
                      ? const Color(0xFFFFEBEE)
                      : (task.isCompleted ? const Color(0xFFE8F5E9) : Colors.grey[100]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  task.isActive ? '进行中' : (task.isCompleted ? '已完成' : '已放弃'),
                  style: TextStyle(
                    fontSize: 12,
                    color: task.isActive
                        ? const Color(0xFFFF6B9D)
                        : (task.isCompleted ? const Color(0xFF4CAF50) : Colors.grey),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _infoRow('学段/分类', _levelLabel()),
          _infoRow('总词数', '${task.totalWords} 词'),
          _infoRow('每日目标', '${task.dailyGoal} 词/天'),
          _infoRow('开始日期', '${task.startDate.year}/${task.startDate.month}/${task.startDate.day}'),
          _infoRow('截止日期', '${task.deadline.year}/${task.deadline.month}/${task.deadline.day}'),
          _infoRow('已学词数', '$_totalLearned 词'),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation(Color(0xFFFF6B9D)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildScoreCard() {
    final task = widget.task;
    final stars = task.stars ?? 0;
    final completedDays = _dailyTasks.where((d) => d.isCompleted).length;
    final overdueDays = _dailyTasks.where((d) => d.isOverdue).length;
    final totalDays = _dailyTasks.length;
    final completionRate = totalDays == 0 ? 0.0 : completedDays / totalDays;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  i < stars ? Icons.star : Icons.star_border,
                  size: 36,
                  color: i < stars ? const Color(0xFFFFB300) : Colors.grey[400],
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _scoreItem('${(completionRate * 100).toInt()}%', '完成率'),
              _scoreItem('$completedDays/$totalDays', '完成天数'),
              _scoreItem('$overdueDays', '逾期天数'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scoreItem(String value, String label) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.6))),
      ],
    );
  }

  Widget _buildDailyTasksList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('每日任务', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ..._dailyTasks.map((dt) => _buildDailyTaskItem(dt)),
      ],
    );
  }

  Widget _buildDailyTaskItem(DailyTask dt) {
    final isToday = _isSameDay(dt.date, DateTime.now());
    final icon = switch (dt.status) {
      DailyTaskStatus.completed => Icons.check_circle,
      DailyTaskStatus.overdue => Icons.cancel,
      DailyTaskStatus.pending => Icons.radio_button_unchecked,
    };
    final iconColor = switch (dt.status) {
      DailyTaskStatus.completed => const Color(0xFF4CAF50),
      DailyTaskStatus.overdue => Colors.red,
      DailyTaskStatus.pending => Colors.grey[400]!,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isToday ? const Color(0xFFFFEBEE) : (Theme.of(context).cardTheme.color ?? Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: isToday ? Border.all(color: const Color(0xFFFF6B9D), width: 1) : null,
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${dt.date.month}/${dt.date.day}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                Text(
                  '目标 ${dt.targetCount} 词 · 已学 ${dt.learnedCount} 词',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          if (isToday)
            const Text('今天', style: TextStyle(fontSize: 12, color: Color(0xFFFF6B9D), fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
