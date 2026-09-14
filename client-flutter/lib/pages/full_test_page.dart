import 'dart:math';

import 'package:flutter/material.dart';

import '../db/user_database.dart';
import '../models/word.dart';
import '../services/audio_service.dart';
import '../utils/resource_helper.dart';
import '../widgets/smart_image.dart';
import 'practice_result_page.dart';

/// 统一测试页
///
/// 每个单词测试 3 次：翻译 + 听力(A/B 随机) + 默写(A/B/C 随机)
/// 三次都对才算通过。
/// 内部把 (word, type, variant) 展平为 List<TestItem> 并全局 shuffle。
class FullTestPage extends StatefulWidget {
  final List<Word> words;
  final List<Word>? optionPool;
  final int? taskId;
  final int? dailyTaskId;
  final String practiceMode;

  const FullTestPage({
    super.key,
    required this.words,
    this.optionPool,
    this.taskId,
    this.dailyTaskId,
    this.practiceMode = 'test',
  });

  @override
  State<FullTestPage> createState() => _FullTestPageState();
}

enum _TestType { translation, listening, dictation }

class _TestItem {
  final Word word;
  final _TestType type;
  final String variant; // 听力: 'image'|'text'；默写: 'audio'|'image'|'text'

  _TestItem({required this.word, required this.type, required this.variant});
}

class _FullTestPageState extends State<FullTestPage> {
  late final List<_TestItem> _items;
  int _currentIndex = 0;
  final List<Map<String, dynamic>> _translationDetails = [];
  final List<Map<String, dynamic>> _listeningDetails = [];
  final List<Map<String, dynamic>> _dictationDetails = [];

  // 翻译/听力题状态
  bool _hasAnswered = false;
  int? _selectedIndex;
  late List<String> _translationOptions;
  late List<Word> _listeningOptions;

  // 默写题状态
  final TextEditingController _dictationController = TextEditingController();
  final FocusNode _dictationFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _items = _buildItems();
    if (_items.isNotEmpty) {
      _loadCurrentQuestion();
    }
  }

  List<_TestItem> _buildItems() {
    final rng = Random();
    final items = <_TestItem>[];
    for (final w in widget.words) {
      items.add(_TestItem(word: w, type: _TestType.translation, variant: ''));
      items.add(_TestItem(
        word: w,
        type: _TestType.listening,
        variant: rng.nextBool() ? 'image' : 'text',
      ));
      items.add(_TestItem(
        word: w,
        type: _TestType.dictation,
        variant: ['audio', 'image', 'text'][rng.nextInt(3)],
      ));
    }
    items.shuffle(rng);
    return items;
  }

  void _loadCurrentQuestion() {
    _hasAnswered = false;
    _selectedIndex = null;
    _dictationController.clear();
    final item = _items[_currentIndex];
    switch (item.type) {
      case _TestType.translation:
        _translationOptions = _generateTranslationOptions(item.word);
        break;
      case _TestType.listening:
        _listeningOptions = _generateListeningOptions(item.word);
        AudioService.instance.play(item.word.audio);
        break;
      case _TestType.dictation:
        if (item.variant == 'audio') {
          AudioService.instance.play(item.word.audio);
        }
        _dictationFocus.requestFocus();
        break;
    }
  }

  // ========== 翻译 ==========

  List<String> _generateTranslationOptions(Word correctWord) {
    final candidates = <String>{};
    for (final w in widget.words) {
      if (w.id != correctWord.id) candidates.add(w.myWord);
    }
    if (widget.optionPool != null) {
      for (final w in widget.optionPool!) {
        if (w.id != correctWord.id) candidates.add(w.myWord);
      }
    }
    final list = candidates.toList()..shuffle();
    final wrong = list.take(3).toList();
    final all = [...wrong, correctWord.myWord]..shuffle();
    return all;
  }

  void _onTranslationSelect(int index) {
    if (_hasAnswered) return;
    final item = _items[_currentIndex];
    final correct = _translationOptions[index] == item.word.myWord;
    setState(() {
      _hasAnswered = true;
      _selectedIndex = index;
    });
    _translationDetails.add({
      'word': item.word.word,
      'is_correct': correct ? 1 : 0,
    });
    Future.delayed(const Duration(milliseconds: 600), _next);
  }

  // ========== 听力 ==========

  List<Word> _generateListeningOptions(Word correctWord) {
    final candidates = <int, Word>{};
    for (final w in widget.words) {
      if (w.id != correctWord.id) candidates[w.id ?? 0] = w;
    }
    if (widget.optionPool != null) {
      for (final w in widget.optionPool!) {
        if (w.id != correctWord.id) candidates[w.id ?? 0] = w;
      }
    }
    final list = candidates.values.toList()..shuffle();
    final wrong = list.take(3).toList();
    final all = [...wrong, correctWord]..shuffle();
    return all;
  }

  void _onListeningSelect(int index) {
    if (_hasAnswered) return;
    final item = _items[_currentIndex];
    final correct = _listeningOptions[index].id == item.word.id;
    setState(() {
      _hasAnswered = true;
      _selectedIndex = index;
    });
    _listeningDetails.add({
      'word': item.word.word,
      'is_correct': correct ? 1 : 0,
    });
    Future.delayed(const Duration(milliseconds: 600), _next);
  }

  void _replayListening() {
    AudioService.instance.play(_items[_currentIndex].word.audio);
  }

  // ========== 默写 ==========

  void _onDictationSubmit() {
    final item = _items[_currentIndex];
    final input = _dictationController.text.trim().toLowerCase();
    final correct = input == item.word.learnWord.toLowerCase().trim();
    _dictationDetails.add({
      'word': item.word.word,
      'is_correct': correct ? 1 : 0,
    });
    if (!correct && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('正确答案: ${item.word.learnWord}'),
          duration: const Duration(milliseconds: 800),
        ),
      );
    }
    Future.delayed(const Duration(milliseconds: 800), _next);
  }

  // ========== 流转 ==========

  void _next() {
    if (!mounted) return;
    if (_currentIndex < _items.length - 1) {
      setState(() {
        _currentIndex++;
        _loadCurrentQuestion();
      });
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    // 按 type 分别写入 practice_result（每种 type 的 details 一起提交）
    if (_translationDetails.isNotEmpty) {
      await UserDatabase.instance.insertPracticeResult(
        type: 'translation',
        totalCount: _translationDetails.length,
        correctCount: _translationDetails
            .where((d) => (d['is_correct'] as int) == 1)
            .length,
        details: _translationDetails,
        taskId: widget.taskId,
        dailyTaskId: widget.dailyTaskId,
        mode: widget.practiceMode,
      );
    }
    if (_listeningDetails.isNotEmpty) {
      await UserDatabase.instance.insertPracticeResult(
        type: 'listening',
        totalCount: _listeningDetails.length,
        correctCount: _listeningDetails
            .where((d) => (d['is_correct'] as int) == 1)
            .length,
        details: _listeningDetails,
        taskId: widget.taskId,
        dailyTaskId: widget.dailyTaskId,
        mode: widget.practiceMode,
      );
    }
    if (_dictationDetails.isNotEmpty) {
      await UserDatabase.instance.insertPracticeResult(
        type: 'dictation',
        totalCount: _dictationDetails.length,
        correctCount: _dictationDetails
            .where((d) => (d['is_correct'] as int) == 1)
            .length,
        details: _dictationDetails,
        taskId: widget.taskId,
        dailyTaskId: widget.dailyTaskId,
        mode: widget.practiceMode,
      );
    }

    // 统计每个单词三项全对的数量
    final wordPassCount = <String, int>{};
    for (final d in _translationDetails) {
      if ((d['is_correct'] as int) == 1) {
        wordPassCount[d['word'] as String] =
            (wordPassCount[d['word'] as String] ?? 0) + 1;
      }
    }
    for (final d in _listeningDetails) {
      if ((d['is_correct'] as int) == 1) {
        wordPassCount[d['word'] as String] =
            (wordPassCount[d['word'] as String] ?? 0) + 1;
      }
    }
    for (final d in _dictationDetails) {
      if ((d['is_correct'] as int) == 1) {
        wordPassCount[d['word'] as String] =
            (wordPassCount[d['word'] as String] ?? 0) + 1;
      }
    }
    final passedWords = wordPassCount.values.where((c) => c >= 3).length;
    final totalWords = widget.words.length;

    if (mounted) {
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PracticeResultPage(
            type: 'full_test',
            totalCount: totalWords,
            correctCount: passedWords,
            resultId: -1,
          ),
        ),
      );
    }
  }

  // ========== Build ==========

  @override
  void dispose() {
    AudioService.instance.stop();
    _dictationController.dispose();
    _dictationFocus.dispose();
    super.dispose();
  }

  Color _optionColor(int index, bool correct) {
    if (!_hasAnswered) return Colors.white;
    if (correct) return Colors.green.shade100;
    if (_selectedIndex == index) return Colors.red.shade100;
    return Colors.white;
  }

  Widget _buildTranslationView() {
    final item = _items[_currentIndex];
    final word = item.word;
    final displayLearn = word.abbreviation != null && word.abbreviation!.isNotEmpty
        ? '${word.abbreviation} · ${word.learnWord}'
        : word.learnWord;
    return Column(
      children: [
        Text(displayLearn,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
        if (word.description != null && word.description!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(word.description!,
                style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          ),
        const SizedBox(height: 32),
        Expanded(
          child: ListView.separated(
            itemCount: _translationOptions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final isCorrect = _translationOptions[index] == word.myWord;
              return ElevatedButton(
                onPressed: () => _onTranslationSelect(index),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _optionColor(index, isCorrect),
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(_translationOptions[index],
                    style: const TextStyle(fontSize: 16)),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildListeningView() {
    final item = _items[_currentIndex];
    final variant = item.variant;
    return Column(
      children: [
        GestureDetector(
          onTap: _replayListening,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.blue, width: 2),
            ),
            child: const Icon(Icons.volume_up, size: 48, color: Colors.blue),
          ),
        ),
        const SizedBox(height: 12),
        const Text('点击图标播放音频', style: TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 24),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
            ),
            itemCount: _listeningOptions.length,
            itemBuilder: (context, index) {
              final opt = _listeningOptions[index];
              final isCorrect = opt.id == item.word.id;
              return ElevatedButton(
                onPressed: () => _onListeningSelect(index),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _optionColor(index, isCorrect),
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.all(8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: variant == 'text'
                    ? Text(opt.myWord,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SmartImage(
                          source: ResourceHelper.resolveUrl(opt.image),
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          memCacheWidth: 80,
                          memCacheHeight: 80,
                        ),
                      ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDictationView() {
    final item = _items[_currentIndex];
    final variant = item.variant;
    Widget prompt;
    switch (variant) {
      case 'audio':
        prompt = Column(
          children: [
            GestureDetector(
              onTap: _replayListening,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.blue, width: 2),
                ),
                child: const Icon(Icons.volume_up, size: 48, color: Colors.blue),
              ),
            ),
            const SizedBox(height: 12),
            const Text('点击图标播放音频', style: TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        );
        break;
      case 'image':
        prompt = ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SmartImage(
            source: ResourceHelper.resolveUrl(item.word.image),
            width: 120,
            height: 120,
            fit: BoxFit.cover,
            memCacheWidth: 120,
            memCacheHeight: 120,
          ),
        );
        break;
      default:
        prompt = Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Text(item.word.myWord,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
        );
    }
    return Column(
      children: [
        prompt,
        const SizedBox(height: 32),
        TextField(
          controller: _dictationController,
          focusNode: _dictationFocus,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20),
          decoration: InputDecoration(
            hintText: '请输入单词',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onSubmitted: (_) => _onDictationSubmit(),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _onDictationSubmit,
            child: const Text('确认', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  String get _typeLabel {
    return switch (_items[_currentIndex].type) {
      _TestType.translation => '翻译',
      _TestType.listening => '听力',
      _TestType.dictation => '默写',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: const Text('测试'),
        ),
        body: const Center(child: Text('没有单词数据')),
      );
    }
    final item = _items[_currentIndex];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('${_typeLabel}测试 (${_currentIndex + 1}/${_items.length})',
            overflow: TextOverflow.ellipsis),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            LinearProgressIndicator(value: (_currentIndex + 1) / _items.length),
            const SizedBox(height: 24),
            Expanded(
              child: switch (item.type) {
                _TestType.translation => _buildTranslationView(),
                _TestType.listening => _buildListeningView(),
                _TestType.dictation => _buildDictationView(),
              },
            ),
          ],
        ),
      ),
    );
  }
}
