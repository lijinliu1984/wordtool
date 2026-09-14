import 'package:flutter/material.dart';

import '../db/user_database.dart';
import '../models/task.dart';
import 'task_edit_page.dart';
import 'task_word_list_page.dart';

/// 任务列表页（从首页「更多」按钮进入）
class TaskListPage extends StatefulWidget {
  const TaskListPage({super.key});

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
  Task? _activeTask;
  List<Task> _historyTasks = [];
  int _totalLearnedCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      _activeTask = await UserDatabase.instance.getActiveTask();
      if (_activeTask != null) {
        await UserDatabase.instance.checkOverdueDailyTasks(_activeTask!.id!);
        await UserDatabase.instance.checkTaskCompletion(_activeTask!.id!);
        _activeTask = await UserDatabase.instance.getActiveTask();
        _totalLearnedCount = await UserDatabase.instance.getTaskLearnedWordCount(_activeTask!);
      }
      _historyTasks = await UserDatabase.instance.getHistoryTasks();
    } catch (e) {
      debugPrint('任务列表加载失败: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openTaskEdit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TaskEditPage(task: _activeTask)),
    );
    if (result == true) _loadData();
  }

  Future<void> _navigateToWordList(Task task) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TaskWordListPage(task: task)),
    );
    if (result == true) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('学习任务'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_activeTask != null) _buildActiveTaskCard(_activeTask!),
                      if (_activeTask != null && _historyTasks.isNotEmpty)
                        const SizedBox(height: 24),
                      if (_historyTasks.isNotEmpty) ...[
                        const Text(
                          '历史任务',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        ..._historyTasks.map((t) => _buildHistoryTaskCard(t)),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildActiveTaskCard(Task task) {
    final progress = task.totalWords == 0
        ? 0.0
        : (_totalLearnedCount / task.totalWords).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () => _navigateToWordList(task),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFB300).withValues(alpha: 0.1),
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
                Expanded(
                  child: Text(
                    '当前任务: ${task.name}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildStatusBadge(task),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: _openTaskEdit,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B9D).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add, size: 18, color: Color(0xFFFF6B9D)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${(progress * 100).toInt()}%',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF6B9D),
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation(Color(0xFFFF6B9D)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '已背 $_totalLearnedCount/${task.totalWords} 词',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                Text(
                  '截止 ${task.deadline.month}月${task.deadline.day}日',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTaskCard(Task task) {
    return GestureDetector(
      onTap: () => _navigateToWordList(task),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFB300).withValues(alpha: 0.1),
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
                Expanded(
                  child: Text(
                    '历史任务: ${task.name}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildStatusBadge(task),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${task.totalWords} 词',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF6B9D),
                  ),
                ),
                Row(
                  children: List.generate(5, (i) {
                    final filled = i < (task.stars ?? 0);
                    return Icon(
                      filled ? Icons.star : Icons.star_border,
                      size: 18,
                      color: filled ? const Color(0xFFFFB300) : Colors.grey[400],
                    );
                  }),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  task.status == TaskStatus.completed ? '已完成' : '已放弃',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                Text(
                  '截止 ${task.deadline.month}月${task.deadline.day}日',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(Task task) {
    String label;
    Color bg;
    Color fg;
    if (task.isCompleted) {
      label = '已完成';
      bg = const Color(0xFFE8F5E9);
      fg = const Color(0xFF4CAF50);
    } else if (task.isActive && DateTime.now().isAfter(task.deadline)) {
      label = '延期';
      bg = const Color(0xFFFFEBEE);
      fg = const Color(0xFFF44336);
    } else {
      label = '进行中';
      bg = const Color(0xFFE3F2FD);
      fg = const Color(0xFF5B8DEF);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: fg,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
