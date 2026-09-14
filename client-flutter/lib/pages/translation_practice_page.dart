import 'package:flutter/material.dart';

import '../db/user_database.dart';
import '../models/word.dart';
import 'practice_result_page.dart';

class TranslationPracticePage extends StatefulWidget {
  final List<Word> words;
  final List<Word>? optionPool;
  final int? taskId;
  final int? dailyTaskId;
  final String practiceMode;

  const TranslationPracticePage({
    super.key,
    required this.words,
    this.optionPool,
    this.taskId,
    this.dailyTaskId,
    this.practiceMode = 'practice',
  });

  @override
  State<TranslationPracticePage> createState() =>
      _TranslationPracticePageState();
}

class _TranslationPracticePageState extends State<TranslationPracticePage> {
  late final List<Word> _questions;
  int _currentIndex = 0;
  int _correctCount = 0;
  bool _hasAnswered = false;
  int? _selectedIndex;
  late List<String> _options;
  final List<Map<String, dynamic>> _details = [];

  @override
  void initState() {
    super.initState();
    _questions = List<Word>.from(widget.words)..shuffle();
    _loadQuestion();
  }

  void _loadQuestion() {
    _hasAnswered = false;
    _selectedIndex = null;
    _options = _generateOptions(_questions[_currentIndex]);
  }

  List<String> _generateOptions(Word correctWord) {
    // 候选干扰项：今日其他单词 + 选项池
    final candidates = <String>{};
    for (final w in widget.words) {
      if (w.id != correctWord.id) candidates.add(w.myWord);
    }
    if (widget.optionPool != null) {
      for (final w in widget.optionPool!) {
        if (w.id != correctWord.id) candidates.add(w.myWord);
      }
    }

    final candidateList = candidates.toList()..shuffle();
    final wrongOptions = candidateList.take(3).toList();
    final options = [...wrongOptions, correctWord.myWord];
    options.shuffle();
    return options;
  }

  void _onSelect(int index) {
    if (_hasAnswered) return;

    final correct = _options[index] == _questions[_currentIndex].myWord;
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
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final resultId = await UserDatabase.instance.insertPracticeResult(
      type: 'translation',
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
            type: 'translation',
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
    final isCorrectOption = _options[index] == _questions[_currentIndex].myWord;
    if (isCorrectOption) return Colors.green.shade100;
    if (_selectedIndex == index) return Colors.red.shade100;
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final word = _questions[_currentIndex];
    final displayLearnWord =
        word.abbreviation != null && word.abbreviation!.isNotEmpty
        ? '${word.abbreviation} · ${word.learnWord}'
        : word.learnWord;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(
          '翻译练习 (${_currentIndex + 1}/${_questions.length})',
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
            Text(
              displayLearnWord,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            if (word.description != null && word.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  word.description!,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ),
            const SizedBox(height: 40),
            Expanded(
              child: ListView.separated(
                itemCount: _options.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return ElevatedButton(
                    onPressed: () => _onSelect(index),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _optionColor(index),
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _options[index],
                      style: const TextStyle(fontSize: 16),
                    ),
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
