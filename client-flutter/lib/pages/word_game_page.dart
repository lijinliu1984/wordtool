import 'dart:math';

import 'package:flutter/material.dart';

import '../db/user_database.dart';
import '../models/word.dart';
import '../services/audio_service.dart';
import '../utils/resource_helper.dart';
import '../widgets/smart_image.dart';

/// 单词消消乐游戏页面
class WordGamePage extends StatefulWidget {
  final int? taskId;
  final List<Word>? words;

  const WordGamePage({super.key, this.taskId, this.words})
      : assert(taskId != null || words != null,
            'taskId 或 words 必须传一个');

  @override
  State<WordGamePage> createState() => _WordGamePageState();
}

class _WordGamePageState extends State<WordGamePage> {
  List<Word> _allWords = [];
  List<Word> _gameWords = []; // 当前游戏中的单词（移除后从中删除）
  int _currentTargetIndex = 0; // 当前要消除的词在 _gameWords 中的索引
  bool _isLoading = true;
  String? _error;
  bool _isPlaying = false;
  bool _showWord = false; // 单词文本开关

  final Random _random = Random();

  /// 当前需要找出的词
  Word? get _currentWord =>
      _gameWords.isNotEmpty && _currentTargetIndex < _gameWords.length
          ? _gameWords[_currentTargetIndex]
          : null;

  int get _remainingCount => _gameWords.length;

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  Future<void> _loadWords() async {
    try {
      List<Word> rawWords;
      if (widget.words != null) {
        rawWords = widget.words!;
      } else {
        rawWords = await UserDatabase.instance.getTaskWords(widget.taskId!);
      }
      if (!mounted) return;
      if (rawWords.isEmpty) {
        setState(() { _isLoading = false; _error = '没有可用的单词'; });
        return;
      }
      // 过滤有图片的单词
      _allWords = rawWords.where((w) {
        final url = ResourceHelper.resolveUrl(w.pic);
        return url != null && url.isNotEmpty;
      }).toList();

      if (_allWords.isEmpty) {
        setState(() { _isLoading = false; _error = '没有带图片的单词'; });
        return;
      }

      _gameWords = List.from(_allWords)..shuffle(Random());
      _currentTargetIndex = _gameWords.isNotEmpty ? _random.nextInt(_gameWords.length) : 0;
      setState(() => _isLoading = false);
      _playCurrentAudio();
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _playCurrentAudio() async {
    final word = _currentWord;
    if (word == null) return;
    setState(() => _isPlaying = true);
    await AudioService.instance.play(word.audio);
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _isPlaying = false);
  }

  void _pickNextTarget() {
    if (_gameWords.isEmpty) return;
    setState(() {
      _currentTargetIndex = _random.nextInt(_gameWords.length);
    });
    _playCurrentAudio();
  }

  void _onImageTap(Word word) {
    if (_currentWord == null) return;
    if (word.id == _currentWord!.id) {
      // 正确：移除该词（从后往前删避免 index 漂移），重新随机选目标
      final removedIdx = _gameWords.indexWhere((w) => w.id == word.id);
      setState(() => _gameWords.removeAt(removedIdx));
      if (_gameWords.isEmpty) {
        _showCompletionDialog();
      } else {
        _pickNextTarget();
      }
    } else {
      // 错误：先清空旧的提示再展示，避免连续乱点时排队堆积
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('错误，再试一次！'),
          duration: Duration(milliseconds: 800),
        ),
      );
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.celebration, color: Color(0xFFFF6B9D)),
            SizedBox(width: 8),
            Text('恭喜通关！'),
          ],
        ),
        content: Text(
          '你消除了 ${_allWords.length} 个单词，太棒了！',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
            child: const Text('返回'),
          ),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _restartGame(); },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B9D),
              foregroundColor: Colors.white,
            ),
            child: const Text('再来一次'),
          ),
        ],
      ),
    );
  }

  void _restartGame() {
    setState(() {
      _gameWords = List.from(_allWords)..shuffle(Random());
      _currentTargetIndex = _gameWords.isNotEmpty ? _random.nextInt(_gameWords.length) : 0;
    });
    _playCurrentAudio();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('单词消消乐'),
        actions: [
          // 单词文本开关
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '显示单词',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
              Switch(
                value: _showWord,
                onChanged: (v) => setState(() => _showWord = v),
                activeColor: Colors.white,
                activeTrackColor: const Color(0xFFFF6B9D).withValues(alpha: 0.5),
                inactiveThumbColor: Colors.grey[300],
                inactiveTrackColor: Colors.grey[600],
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('返回'),
            ),
          ],
        ),
      );
    }

    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 12),
          // 剩余计数
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '剩余: $_remainingCount / ${_allWords.length}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 播放按钮（缩小）
          GestureDetector(
            onTap: _playCurrentAudio,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B9D),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6B9D).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                _isPlaying ? Icons.volume_up : Icons.play_arrow,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 当前单词（开关控制）
          if (_currentWord != null && _showWord)
            Text(
              _currentWord!.word,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          const SizedBox(height: 12),
          // 图片网格（无空白）
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: _gameWords.length,
                  itemBuilder: (context, index) {
                    final word = _gameWords[index];
                    final imageUrl = ResourceHelper.resolveUrl(word.pic);

                    return GestureDetector(
                      onTap: () => _onImageTap(word),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey[100],
                        ),
                        child: imageUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SmartImage(
                                  source: imageUrl,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 200,
                                  memCacheHeight: 200,
                                ),
                              )
                            : Center(
                                child: Text(
                                  word.word,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
