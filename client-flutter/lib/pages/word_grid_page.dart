import 'package:flutter/material.dart';

import '../db/user_database.dart';
import '../db/vocabulary_database.dart';
import '../models/word.dart';
import '../models/word_filter.dart';
import '../services/audio_service.dart';
import '../utils/resource_helper.dart';
import '../widgets/smart_image.dart';
import 'home_page.dart';
import 'task_edit_page.dart';
import 'word_game_page.dart';
import 'word_image_edit_page.dart';

class WordGridPage extends StatefulWidget {
  final WordFilter filter;
  final String? title;

  const WordGridPage({super.key, required this.filter, this.title});

  @override
  State<WordGridPage> createState() => _WordGridPageState();
}

class _WordGridPageState extends State<WordGridPage> {
  final ValueNotifier<int?> _speakingWordId = ValueNotifier(null);
  final ScrollController _scrollController = ScrollController();

  static const int _pageSize = 50;

  int _currentPage = 1;
  int _totalCount = 0;
  List<Word> _pageWords = [];
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
      final count =
          await VocabularyDatabase.instance.getWordCount(widget.filter);
      final words = await VocabularyDatabase.instance.getWords(
        widget.filter,
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

  Future<void> _loadPage(int page) async {
    if (_isLoading || page < 1 || page > _totalPages || page == _currentPage) {
      return;
    }
    setState(() => _isLoading = true);
    try {
      final words = await VocabularyDatabase.instance.getWords(
        widget.filter,
        limit: _pageSize,
        offset: (page - 1) * _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _pageWords = words;
        _currentPage = page;
        _isLoading = false;
      });
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
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
    // 播放完成后重置状态（延迟一段时间）
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      _speakingWordId.value = null;
    }
  }


  Future<void> _addToCurrentTask() async {
    final words =
        await VocabularyDatabase.instance.getWords(widget.filter);
    if (words.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前没有单词数据')),
        );
      }
      return;
    }

    final activeTask = await UserDatabase.instance.getActiveTask();
    if (activeTask == null || activeTask.id == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前没有进行中的任务')),
        );
      }
      return;
    }

    if (!mounted) return;

    // 检查是否超上限
    final currentCount = await UserDatabase.instance.getTaskWordCount(activeTask.id!);
    final remaining = UserDatabase.maxWordsPerTask - currentCount;
    if (words.length > remaining) {
      if (mounted) {
        final goTaskEdit = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('单词数量超限'),
            content: Text(
              '任务「${activeTask.name}」最多 ${UserDatabase.maxWordsPerTask} 个单词，'
              '已有 $currentCount 个，还能添加 $remaining 个，'
              '当前尝试添加 ${words.length} 个。\n\n'
              '是否仅添加前 $remaining 个单词？',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text('只加 $remaining 个')),
            ],
          ),
        );
        if (goTaskEdit == true) {
          await _doAddWords(activeTask.id!, words.take(remaining).toList());
        }
      }
      return;
    }

    await _doAddWords(activeTask.id!, words);
  }

  Future<void> _doAddWords(int taskId, List<Word> words) async {
    // 显示进度弹窗
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ProgressDialog(message: '正在添加单词...'),
    );

    try {
      final added = await UserDatabase.instance.addWordsToTask(
        taskId,
        words,
        onProgress: (current, total) {
          // 进度更新
        },
      );
      if (mounted) {
        Navigator.pop(context); // 关闭进度弹窗
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已添加 $added 个单词到任务')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // 关闭进度弹窗
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加失败: $e')),
        );
      }
    }
  }

  void _createTaskWithWords() async {
    // 先检查是否已有任务
    final activeTask = await UserDatabase.instance.getActiveTask();
    if (activeTask != null && activeTask.id != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前已有一个任务，请先删除当前任务')),
        );
      }
      return;
    }

    final words = await VocabularyDatabase.instance.getWords(widget.filter);
    if (words.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前没有单词数据')),
        );
      }
      return;
    }

    if (words.length > UserDatabase.maxWordsPerTask) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('当前分类有 ${words.length} 个单词，任务上限 ${UserDatabase.maxWordsPerTask} 个，请缩小筛选范围'),
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskEditPage(preSelectedWords: words),
      ),
    );

    // 创建任务后返回首页并刷新
    if (mounted) {
      Navigator.popUntil(context, (route) => route.isFirst);
      HomePage.globalKey.currentState?.refresh();
    }
  }

  Future<void> _onImageTap(Word word) async {
    final newPic = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => WordImageEditPage(word: word),
      ),
    );
    if (newPic != null && mounted) {
      setState(() {
        final idx = _pageWords.indexWhere((w) => w.id == word.id);
        if (idx >= 0) {
          _pageWords[idx] = _pageWords[idx].copyWith(pic: newPic);
        }
      });
    }
  }

  Future<void> _openGame() async {
    final withImage = _pageWords.where((w) {
      final url = ResourceHelper.resolveUrl(w.pic);
      return url != null && url.isNotEmpty;
    }).toList();
    if (withImage.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前页面没有带图片的单词')),
        );
      }
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WordGamePage(words: withImage),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(
          widget.title ?? '单词列表',
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.add, color: Colors.white),
            offset: const Offset(0, 40),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              if (value == 'add_to_task') _addToCurrentTask();
              if (value == 'create_task') _createTaskWithWords();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'add_to_task',
                child: ListTile(
                  leading: Icon(Icons.playlist_add),
                  title: Text('加入当前任务'),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const PopupMenuItem(
                value: 'create_task',
                child: ListTile(
                  leading: Icon(Icons.add_task),
                  title: Text('创建新任务'),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
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
        onPressed: _openGame,
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
      return const Center(child: Text('暂无数据'));
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: _pageWords.length,
      itemBuilder: (context, index) {
        final word = _pageWords[index];
        final imageUrl = ResourceHelper.resolveUrl(word.image);
        final hasImage = imageUrl != null && imageUrl.isNotEmpty;

        return GestureDetector(
          onTap: () => _speakWord(word.audio, word.id ?? index),
          child: Card(
            elevation: 1,
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (hasImage)
                    GestureDetector(
                      onTap: () => _onImageTap(word),
                      child: ClipRRect(
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
                                        word.abbreviation != null &&
                                                word.abbreviation!.isNotEmpty
                                            ? '${word.abbreviation} · ${word.learnWord}'
                                            : word.learnWord,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (word.description != null &&
                                        word.description!.isNotEmpty) ...[
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          '[${word.description}]',
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
                                  word.myWord,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[700],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
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
                                final isSpeaking =
                                    speakingId == (word.id ?? index);
                                return GestureDetector(
                                  onTap: () => _speakWord(
                                      word.audio, word.id ?? index),
                                  child: AnimatedScale(
                                    scale: isSpeaking ? 1.35 : 1.0,
                                    duration:
                                        const Duration(milliseconds: 200),
                                    child: Icon(
                                      Icons.volume_up,
                                      size: 16,
                                      color: isSpeaking
                                          ? Colors.green
                                          : Colors.blue,
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
        );
      },
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
                    color: isCurrent
                        ? const Color(0xFFFF6B9D)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$page',
                    style: TextStyle(
                      fontSize: 13,
                      color: isCurrent ? Colors.white : Colors.grey[700],
                      fontWeight:
                          isCurrent ? FontWeight.bold : FontWeight.normal,
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
        child: Icon(icon,
            size: 20,
            color: enabled ? const Color(0xFFFF6B9D) : Colors.grey[400]),
      ),
    );
  }
}

/// 保存/插入进度弹窗
class _ProgressDialog extends StatelessWidget {
  final String message;
  final double? progress;

  const _ProgressDialog({required this.message, this.progress});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
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
    );
  }
}
