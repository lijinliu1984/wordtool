import 'package:flutter/material.dart';

import '../db/user_database.dart';
import '../models/task.dart';
import '../services/audio_service.dart';
import '../utils/resource_helper.dart';
import '../widgets/smart_image.dart';
import 'word_game_page.dart';
import 'word_practice_page.dart';

/// 任务单词列表页：分页 + 左滑删除 + 点击跳练习页
class TaskWordListPage extends StatefulWidget {
  final Task task;

  const TaskWordListPage({super.key, required this.task});

  @override
  State<TaskWordListPage> createState() => _TaskWordListPageState();
}

class _TaskWordListPageState extends State<TaskWordListPage> {
  final ValueNotifier<int?> _speakingWordId = ValueNotifier(null);
  final ScrollController _scrollController = ScrollController();

  static const int _pageSize = 50;

  int _currentPage = 1;
  int _totalCount = 0;
  List<TaskWordInfo> _pageWords = [];
  bool _isLoading = false;
  String? _error;

  int get _totalPages => (_totalCount / _pageSize).ceil();

  @override
  void initState() {
    super.initState();
    _initialLoad();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _speakingWordId.dispose();
    super.dispose();
  }

  Future<void> _initialLoad() async {
    setState(() => _isLoading = true);
    try {
      final count = await UserDatabase.instance.getTaskWordCount(widget.task.id!);
      final words = await UserDatabase.instance.getTaskWordsPage(
        widget.task.id!,
        limit: _pageSize,
        offset: 0,
      );
      if (!mounted) return;
      setState(() {
        _totalCount = count;
        _pageWords = words;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPage(int page, {bool force = false}) async {
    if (_isLoading || page < 1 || page > _totalPages || (page == _currentPage && !force)) {
      return;
    }
    setState(() => _isLoading = true);
    try {
      final words = await UserDatabase.instance.getTaskWordsPage(
        widget.task.id!,
        limit: _pageSize,
        offset: (page - 1) * _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _pageWords = words;
        _currentPage = page;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('加载失败: $e')));
    }
  }

  Future<void> _speakWord(String? audioPath, int wordId) async {
    _speakingWordId.value = wordId;
    await AudioService.instance.play(audioPath);
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      _speakingWordId.value = null;
    }
  }

  Future<void> _deleteWord(TaskWordInfo info) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认移除'),
        content: Text('将「${info.word.word}」从任务「${widget.task.name}」中移除？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('移除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await UserDatabase.instance.removeTaskWord(widget.task.id!, info.word.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已移除单词')),
      );
      // 刷新当前页（可能最后一页变空）
      _loadPage(_currentPage, force: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('移除失败: $e')),
      );
    }
  }

  Future<void> _navigateToPractice(TaskWordInfo info) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WordPracticePage(
          taskId: widget.task.id!,
          word: info.word,
          date: info.date,
        ),
      ),
    );
    await _loadPage(_currentPage, force: true);
  }

  Future<void> _confirmDeleteTask() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除任务'),
        content: Text('确定要删除任务「${widget.task.name}」吗？删除后无法恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await UserDatabase.instance.deleteTask(widget.task.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('任务已删除')),
      );
      Navigator.pop(context, true); // 返回上一页并通知刷新
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(
          widget.task.name,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        actions: [
          TextButton.icon(
            onPressed: _confirmDeleteTask,
            icon: const Icon(Icons.delete_outline, color: Colors.white, size: 18),
            label: const Text('删除任务', style: TextStyle(color: Colors.white, fontSize: 13)),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading && _pageWords.isNotEmpty)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(child: _buildBody()),
          if (_totalPages > 1) _buildPaginationBar(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WordGamePage(taskId: widget.task.id!),
            ),
          );
        },
        backgroundColor: const Color(0xFFFF6B9D),
        child: const Icon(Icons.sports_esports, color: Colors.white),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null && _pageWords.isEmpty) {
      return Center(child: Text('加载失败: $_error'));
    }
    if (_pageWords.isEmpty) {
      if (_isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return const Center(child: Text('当前任务没有单词'));
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: _pageWords.length,
      itemBuilder: (context, index) {
        final info = _pageWords[index];
        final word = info.word;
        final imageUrl = ResourceHelper.resolveUrl(word.pic);
        final hasImage = imageUrl != null && imageUrl.isNotEmpty;
        final isPracticed = info.audioCount >= 10 &&
            info.spellCount >= 10 &&
            info.readCount >= 10;

        return Dismissible(
          key: ValueKey('${info.word.id}_${info.date}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: Colors.red,
            child: const Icon(Icons.delete, color: Colors.white, size: 28),
          ),
          onDismissed: (_) => _deleteWord(info),
          confirmDismiss: (direction) async {
            return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('确认移除'),
                content: Text('将「${info.word.word}」从任务「${widget.task.name}」中移除？'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('移除', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ) == true;
          },
          child: GestureDetector(
            onTap: () => _navigateToPractice(info),
            child: Card(
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (hasImage)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: SmartImage(
                            source: imageUrl,
                            width: 32,
                            height: 32,
                            fit: BoxFit.contain,
                            memCacheWidth: 32,
                            memCacheHeight: 32,
                          ),
                        ),
                      ),
                    if (hasImage) const SizedBox(width: 8),
                    Expanded(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 56),
                        child: Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 36),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          word.word,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (word.phonetic != null && word.phonetic!.isNotEmpty) ...[
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            '[${word.phonetic}]',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey[600],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    word.translation ?? '',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[700],
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      _practiceCountChip(Icons.volume_up, info.audioCount),
                                      const SizedBox(width: 6),
                                      _practiceCountChip(Icons.edit, info.spellCount),
                                      const SizedBox(width: 6),
                                      _practiceCountChip(Icons.mic, info.readCount),
                                      if (isPracticed) ...[
                                        const SizedBox(width: 8),
                                        Icon(Icons.check_circle, size: 14, color: Colors.green),
                                      ],
                                      if (info.isTodayTestPassed) ...[
                                        const SizedBox(width: 8),
                                        Icon(Icons.verified, size: 14, color: Color(0xFFFFB300)),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: ValueListenableBuilder<int?>(
                                valueListenable: _speakingWordId,
                                builder: (context, speakingId, child) {
                                  final isSpeaking = speakingId == word.id;
                                  return GestureDetector(
                                    onTap: () => _speakWord(word.audio, word.id ?? 0),
                                    child: AnimatedScale(
                                      scale: isSpeaking ? 1.35 : 1.0,
                                      duration: const Duration(milliseconds: 200),
                                      child: Icon(
                                        Icons.volume_up,
                                        size: 16,
                                        color: isSpeaking ? Colors.green : Colors.blue,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _practiceCountChip(IconData icon, int count) {
    final done = count >= 10;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: done ? Colors.green.withValues(alpha: 0.1) : Colors.grey[100],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: done ? Colors.green : Colors.grey[600]),
          const SizedBox(width: 2),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 9,
              color: done ? Colors.green : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _pageButton(
            Icons.chevron_left,
            !_isLoading && _currentPage > 1,
            () => _loadPage(_currentPage - 1),
          ),
          GestureDetector(
            onTap: _isLoading ? null : _showPagePicker,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '$_currentPage / $_totalPages 页',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ),
          ),
          _pageButton(
            Icons.chevron_right,
            !_isLoading && _currentPage < _totalPages,
            () => _loadPage(_currentPage + 1),
          ),
        ],
      ),
    );
  }

  Future<void> _showPagePicker() async {
    if (_totalPages <= 1) return;
    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('跳转页码（共 $_totalPages 页）'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: GridView.builder(
            itemCount: _totalPages,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.4,
            ),
            itemBuilder: (ctx, index) {
              final page = index + 1;
              final isCurrent = page == _currentPage;
              return GestureDetector(
                onTap: () => Navigator.pop(ctx, page),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isCurrent ? const Color(0xFFFF6B9D) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$page',
                    style: TextStyle(
                      fontSize: 13,
                      color: isCurrent ? Colors.white : Colors.grey[700],
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    if (selected != null && selected != _currentPage) {
      _loadPage(selected);
    }
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
        child: Icon(
          icon,
          size: 20,
          color: enabled ? const Color(0xFFFF6B9D) : Colors.grey[400],
        ),
      ),
    );
  }
}