import 'package:flutter/material.dart';

import '../db/user_database.dart';
import '../models/word.dart';
import '../services/audio_service.dart';
import '../utils/resource_helper.dart';
import '../widgets/smart_image.dart';
import 'practice_result_page.dart';

class ListeningPracticePage extends StatefulWidget {
  final List<Word> words;
  final List<Word>? optionPool;
  final String mode; // 'image' 或 'text'
  final int? taskId;
  final int? dailyTaskId;
  final String practiceMode;

  const ListeningPracticePage({
    super.key,
    required this.words,
    this.optionPool,
    required this.mode,
    this.taskId,
    this.dailyTaskId,
    this.practiceMode = 'practice',
  });

  @override
  State<ListeningPracticePage> createState() => _ListeningPracticePageState();
}

class _ListeningPracticePageState extends State<ListeningPracticePage> {
  late final List<Word> _questions;
  int _currentIndex = 0;
  int _correctCount = 0;
  bool _hasAnswered = false;
  int? _selectedIndex;
  late List<Word> _optionWords;
  final List<Map<String, dynamic>> _details = [];

  @override
  void initState() {
    super.initState();
    _questions = List<Word>.from(widget.words)..shuffle();
    if (_questions.isNotEmpty) {
      _loadQuestion();
      _speakCurrentWord();
    }
  }

  @override
  void dispose() {
    AudioService.instance.stop();
    super.dispose();
  }

  void _loadQuestion() {
    _hasAnswered = false;
    _selectedIndex = null;
    _optionWords = _generateOptions(_questions[_currentIndex]);
  }

  List<Word> _generateOptions(Word correctWord) {
    // 候选干扰项：今日其他单词 + 选项池
    final candidates = <int, Word>{};
    for (final w in widget.words) {
      if (w.id != correctWord.id) candidates[w.id ?? 0] = w;
    }
    if (widget.optionPool != null) {
      for (final w in widget.optionPool!) {
        if (w.id != correctWord.id) candidates[w.id ?? 0] = w;
      }
    }

    final candidateList = candidates.values.toList()..shuffle();
    final wrongOptions = candidateList.take(3).toList();
    final options = [...wrongOptions, correctWord];
    options.shuffle();
    return options;
  }

  Future<void> _speakCurrentWord() async {
    await AudioService.instance.play(_questions[_currentIndex].audio);
  }

  void _onSelect(int index) {
    if (_hasAnswered) return;

    final correct = _optionWords[index].id == _questions[_currentIndex].id;
    setState(() {
      _hasAnswered = true;
      _selectedIndex = index;
      if (correct) _correctCount++;
    });
    _details.add({
      'word': _questions[_currentIndex].word,
      'is_correct': correct ? 1 : 0,
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      _nextQuestion();
    });
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _loadQuestion();
      });
      _speakCurrentWord();
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final resultId = await UserDatabase.instance.insertPracticeResult(
      type: 'listening',
      totalCount: _questions.length,
      correctCount: _correctCount,
      details: _details,
      taskId: widget.taskId,
      dailyTaskId: widget.dailyTaskId,
      mode: widget.practiceMode,
    );

    if (mounted) {
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PracticeResultPage(
            type: 'listening',
            totalCount: _questions.length,
            correctCount: _correctCount,
            resultId: resultId,
          ),
        ),
      );
    }
  }

  Color _optionColor(int index) {
    if (!_hasAnswered) return Colors.white;
    final isCorrectOption =
        _optionWords[index].id == _questions[_currentIndex].id;
    if (isCorrectOption) return Colors.green.shade100;
    if (_selectedIndex == index) return Colors.red.shade100;
    return Colors.white;
  }

  Widget _buildOptionContent(Word word) {
    if (widget.mode == 'text') {
      return _buildTextOption(word.myWord);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SmartImage(
        source: ResourceHelper.resolveUrl(word.image),
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        memCacheWidth: 80,
        memCacheHeight: 80,
      ),
    );
  }

  Widget _buildTextOption(String text) {
    return Container(
      width: 80,
      height: 80,
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(fontSize: 16),
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(
            widget.mode == 'image' ? '听力练习A' : '听力练习B',
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: const Center(
          child: Text(
            '没有音频数据\n无法进行听力练习',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(
          '${widget.mode == 'image' ? '听力练习A' : '听力练习B'} '
          '(${_currentIndex + 1}/${_questions.length})',
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            LinearProgressIndicator(
              value: (_currentIndex + 1) / _questions.length,
            ),
            const SizedBox(height: 40),
            GestureDetector(
              onTap: _speakCurrentWord,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.blue, width: 2),
                ),
                child: const Icon(
                  Icons.volume_up,
                  size: 48,
                  color: Colors.blue,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '点击图标播放音频',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.2,
                ),
                itemCount: _optionWords.length,
                itemBuilder: (context, index) {
                  return ElevatedButton(
                    onPressed: () => _onSelect(index),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _optionColor(index),
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.all(8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _buildOptionContent(_optionWords[index]),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
