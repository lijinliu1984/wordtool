import 'package:flutter/material.dart';

import '../db/user_database.dart';
import '../models/task.dart';
import '../models/word.dart';
import 'word_picker_page.dart';

/// 创建/编辑学习任务
class TaskEditPage extends StatefulWidget {
  final Task? task;
  final List<Word>? preSelectedWords;

  const TaskEditPage({super.key, this.task, this.preSelectedWords});

  @override
  State<TaskEditPage> createState() => _TaskEditPageState();
}

class _TaskEditPageState extends State<TaskEditPage> {
  final _nameController = TextEditingController();
  int _dailyGoal = 10;
  List<Word> _selectedWords = [];
  Set<int> _selectedWordIds = {};
  bool _isLoading = true;
  bool _isSaving = false;

  // 分页
  static const int _pageSize = 50;
  int _currentPage = 1;

  int get _totalPages => (_selectedWords.length / _pageSize).ceil();
  List<Word> get _pageWords {
    final start = (_currentPage - 1) * _pageSize;
    final end = start + _pageSize;
    return _selectedWords.sublist(start, end.clamp(0, _selectedWords.length));
  }

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    try {
      if (widget.preSelectedWords != null) {
        _selectedWords = List.from(widget.preSelectedWords!);
        _selectedWordIds = _selectedWords.map((w) => w.id!).toSet();
      } else if (widget.task != null) {
        _nameController.text = widget.task!.name;
        _dailyGoal = widget.task!.dailyGoal;
        _selectedWords = await UserDatabase.instance.getTaskWords(widget.task!.id!);
        _selectedWordIds = _selectedWords.map((w) => w.id!).toSet();
      }
    } catch (e) {
      debugPrint('加载任务数据失败: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  DateTime? _calculatedDeadline() {
    final totalWords = _selectedWords.length;
    if (_dailyGoal <= 0 || totalWords <= 0) return null;
    final days = (totalWords / _dailyGoal).ceil();
    return DateTime.now().add(Duration(days: days));
  }

  Future<void> _openWordPicker() async {
    final result = await Navigator.push<List<Word>>(
      context,
      MaterialPageRoute(
        builder: (_) => WordPickerPage(
          selectedIds: _selectedWordIds,
          taskId: widget.task?.id,
        ),
      ),
    );
    if (result != null && result.isNotEmpty && mounted) {
      // 检查上限
      final newTotal = _selectedWords.length + result.where((w) => !_selectedWordIds.contains(w.id)).length;
      if (newTotal > UserDatabase.maxWordsPerTask) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('任务最多 ${UserDatabase.maxWordsPerTask} 个单词，当前已选 ${_selectedWords.length} 个')),
          );
        }
        return;
      }

      setState(() {
        for (final w in result) {
          if (w.id != null && !_selectedWordIds.contains(w.id)) {
            _selectedWords.add(w);
            _selectedWordIds.add(w.id!);
          }
        }
        _currentPage = _totalPages;
      });
    }
  }

  void _removeWord(int wordId) {
    setState(() {
      _selectedWords.removeWhere((w) => w.id == wordId);
      _selectedWordIds.remove(wordId);
      if (_currentPage > _totalPages && _totalPages > 0) {
        _currentPage = _totalPages;
      }
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入任务名称')),
      );
      return;
    }
    if (_selectedWords.length < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少添加 1 个单词')),
      );
      return;
    }
    if (_selectedWords.length > UserDatabase.maxWordsPerTask) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('任务最多 ${UserDatabase.maxWordsPerTask} 个单词，当前 ${_selectedWords.length} 个')),
      );
      return;
    }

    setState(() => _isSaving = true);

    // 显示进度弹窗
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _ProgressDialog(message: '正在保存任务...'),
      );
    }

    try {
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, now.day);
      final totalWords = _selectedWords.length;
      final days = (totalWords / _dailyGoal).ceil();
      final deadline = startDate.add(Duration(days: days));

      if (widget.task != null) {
        final updated = widget.task!.copyWith(
          name: name,
          totalWords: totalWords,
          dailyGoal: _dailyGoal,
          deadline: deadline,
        );
        await UserDatabase.instance.updateTask(updated);
        await UserDatabase.instance.clearTaskWords(widget.task!.id!);
        await UserDatabase.instance.insertTaskWordsWithDates(
          widget.task!.id!, _selectedWords, _dailyGoal, widget.task!.startDate,
          onProgress: (current, total) {
            // 进度更新（300词以内很快，不需要实时更新 ui）
          },
        );
      } else {
        final task = Task(
          name: name,
          totalWords: totalWords,
          dailyGoal: _dailyGoal,
          startDate: startDate,
          deadline: deadline,
          createdAt: now,
        );
        await UserDatabase.instance.createTask(task, _selectedWords, onProgress: (current, total) {
          // 进度更新
        });
      }

      if (mounted) {
        Navigator.pop(context); // 进度弹窗
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // 进度弹窗
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.task == null ? '创建任务' : '编辑任务'),
        actions: [
          if (!_isLoading)
            _isSaving
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: TextButton(
                      onPressed: _save,
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFFF6B9D),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('保存', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPreviewCard(),
                  const SizedBox(height: 16),
                  _buildNameField(),
                  const SizedBox(height: 16),
                  _buildDailyGoalSlider(),
                  const SizedBox(height: 16),
                  _buildWordListSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildPreviewCard() {
    final totalWords = _selectedWords.length;
    final deadline = _calculatedDeadline();
    final days = deadline != null
        ? deadline.difference(DateTime.now()).inDays + 1
        : 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFF6B9D).withValues(alpha: 0.1),
            const Color(0xFF6B8CFF).withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('任务预览',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _previewItem('总词数', '$totalWords 词')),
              Expanded(child: _previewItem('每日目标', '$_dailyGoal 词/天')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _previewItem(
                  '预计天数', days > 0 ? '$days 天' : '-')),
              Expanded(child: _previewItem(
                  '截止日期',
                  deadline != null
                      ? '${deadline.month}月${deadline.day}日'
                      : '-')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _previewItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildNameField() {
    return TextField(
      controller: _nameController,
      decoration: const InputDecoration(
        labelText: '任务名称',
        hintText: '例如：高中核心词汇',
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildDailyGoalSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('每日目标词数',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B9D).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$_dailyGoal 词/天',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF6B9D),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Slider(
          value: _dailyGoal.toDouble(),
          min: 1,
          max: 50,
          divisions: 49,
          activeColor: const Color(0xFFFF6B9D),
          inactiveColor: const Color(0xFFFF6B9D).withValues(alpha: 0.2),
          label: '$_dailyGoal',
          onChanged: (v) => setState(() => _dailyGoal = v.round()),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('1', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            Text('50', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ],
        ),
      ],
    );
  }

  Widget _buildWordListSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '单词列表 (${_selectedWords.length}/${UserDatabase.maxWordsPerTask})',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            GestureDetector(
              onTap: _selectedWords.length >= UserDatabase.maxWordsPerTask
                  ? null
                  : _openWordPicker,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: (_selectedWords.length >= UserDatabase.maxWordsPerTask
                      ? Colors.grey[300]
                      : const Color(0xFFFF6B9D).withValues(alpha: 0.1)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.add,
                    color: _selectedWords.length >= UserDatabase.maxWordsPerTask
                        ? Colors.grey
                        : const Color(0xFFFF6B9D),
                    size: 20),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_selectedWords.isEmpty)
          GestureDetector(
            onTap: _openWordPicker,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200, style: BorderStyle.solid),
              ),
              child: Column(
                children: [
                  Icon(Icons.library_add, size: 40, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text('点击添加单词',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                ],
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // 单词列表（当前页）
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: _pageWords.length,
                  itemBuilder: (context, index) {
                    final word = _pageWords[index];
                    return Dismissible(
                      key: ValueKey(word.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        color: Colors.red.shade50,
                        child: const Icon(Icons.delete, color: Colors.red, size: 20),
                      ),
                      onDismissed: (_) => _removeWord(word.id ?? 0),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    word.word,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (word.translation != null)
                                    Text(
                                      word.translation!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _removeWord(word.id ?? 0),
                              child: Icon(Icons.remove_circle_outline,
                                  size: 20, color: Colors.grey[400]),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                // 分页控制
                if (_totalPages > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _pageButton(Icons.chevron_left, _currentPage > 1,
                            () => setState(() => _currentPage--)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            '$_currentPage / $_totalPages 页',
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                        ),
                        _pageButton(Icons.chevron_right, _currentPage < _totalPages,
                            () => setState(() => _currentPage++)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _pageButton(IconData icon, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: enabled
              ? const Color(0xFFFF6B9D).withValues(alpha: 0.1)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 20,
            color: enabled ? const Color(0xFFFF6B9D) : Colors.grey[400]),
      ),
    );
  }
}

/// 保存进度弹窗
class _ProgressDialog extends StatelessWidget {
  final String message;
  final double? progress;

  const _ProgressDialog({required this.message, this.progress});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (progress != null) ...[
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 16),
              Text('${(progress! * 100).toStringAsFixed(0)}%'),
            ] else
              const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    );
  }
}
