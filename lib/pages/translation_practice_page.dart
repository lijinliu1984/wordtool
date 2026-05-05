import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/word.dart';
import 'practice_result_page.dart';

class TranslationPracticePage extends StatefulWidget {
  final List<Word> words;

  const TranslationPracticePage({super.key, required this.words});

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
    final others = widget.words
        .where((w) => w.id != correctWord.id)
        .map((w) => w.myWord)
        .toList();
    others.shuffle();

    final wrongOptions = others.take(3).toList();
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
      'word_id': _questions[_currentIndex].id,
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
    final resultId = await DatabaseHelper.instance.insertPracticeResult(
      type: 'translation',
      totalCount: _questions.length,
      correctCount: _correctCount,
      details: _details,
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
        title: Text('翻译练习 (${_currentIndex + 1}/${_questions.length})'),
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
