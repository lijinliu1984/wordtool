import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

import '../db/database_helper.dart';
import '../models/word.dart';
import '../utils/resource_helper.dart';
import '../widgets/smart_image.dart';
import 'practice_result_page.dart';

class DictationPracticePage extends StatefulWidget {
  final List<Word> words;
  final String mode; // 'audio' | 'image' | 'text'

  const DictationPracticePage({
    super.key,
    required this.words,
    required this.mode,
  });

  @override
  State<DictationPracticePage> createState() => _DictationPracticePageState();
}

class _DictationPracticePageState extends State<DictationPracticePage> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final TextEditingController _controller = TextEditingController();
  late final List<Word> _questions;
  int _currentIndex = 0;
  int _correctCount = 0;
  final List<Map<String, dynamic>> _details = [];
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.mode == 'audio') {
      _questions =
          widget.words
              .where((w) => ResourceHelper.sourceExists(w.audio))
              .toList()
            ..shuffle();
      if (_questions.isNotEmpty) _playCurrentAudio();
    } else {
      _questions = List<Word>.from(widget.words)..shuffle();
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String get _modeTitle {
    return switch (widget.mode) {
      'audio' => '默写练习A',
      'image' => '默写练习B',
      'text' => '默写练习C',
      _ => '默写练习',
    };
  }

  String get _modeSubtitle {
    return switch (widget.mode) {
      'audio' => '听音频，输入单词',
      'image' => '看图片，输入单词',
      'text' => '看译文，输入单词',
      _ => '输入单词',
    };
  }

  Future<void> _playCurrentAudio() async {
    final source = _questions[_currentIndex].audio;
    if (source != null && source.isNotEmpty) {
      try {
        await _audioPlayer.stop();
        final src = ResourceHelper.isUrl(source)
            ? UrlSource(source)
            : DeviceFileSource(source);
        await _audioPlayer.play(src);
      } catch (e) {
        debugPrint('播放失败: $e');
      }
    }
  }

  void _onSubmit() {
    final input = _controller.text.trim().toLowerCase();
    final correctWord = _questions[_currentIndex];
    final correctLearnWord = correctWord.learnWord.toLowerCase().trim();
    final isCorrect = input == correctLearnWord;

    if (isCorrect) _correctCount++;
    _details.add({'word_id': correctWord.id, 'is_correct': isCorrect ? 1 : 0});

    if (!isCorrect && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('正确答案: ${correctWord.learnWord}'),
          duration: const Duration(seconds: 1),
        ),
      );
    }

    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      _nextQuestion();
    });
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _controller.clear();
      });
      if (widget.mode == 'audio') {
        _playCurrentAudio();
      }
      _focusNode.requestFocus();
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final resultId = await DatabaseHelper.instance.insertPracticeResult(
      type: 'dictation',
      totalCount: _questions.length,
      correctCount: _correctCount,
      details: _details,
    );

    if (mounted) {
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PracticeResultPage(
            type: 'dictation',
            totalCount: _questions.length,
            correctCount: _correctCount,
            resultId: resultId,
          ),
        ),
      );
    }
  }

  Widget _buildPrompt() {
    final word = _questions[_currentIndex];

    switch (widget.mode) {
      case 'audio':
        return Column(
          children: [
            GestureDetector(
              onTap: _playCurrentAudio,
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
            const SizedBox(height: 12),
            Text(
              '点击图标播放音频',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        );
      case 'image':
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SmartImage(
            source: word.image,
            width: 120,
            height: 120,
            fit: BoxFit.cover,
            memCacheWidth: 120,
            memCacheHeight: 120,
          ),
        );
      case 'text':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Text(
            word.myWord,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(_modeTitle, overflow: TextOverflow.ellipsis),
        ),
        body: Center(
          child: Text(
            widget.mode == 'audio' ? '没有音频数据\n无法进行默写练习' : '没有单词数据\n无法进行默写练习',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(
          '$_modeTitle (${_currentIndex + 1}/${_questions.length})',
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            LinearProgressIndicator(
              value: (_currentIndex + 1) / _questions.length,
            ),
            const SizedBox(height: 12),
            Text(
              _modeSubtitle,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 40),
            _buildPrompt(),
            const SizedBox(height: 40),
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20),
              decoration: InputDecoration(
                hintText: '请输入单词',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onSubmitted: (_) => _onSubmit(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _onSubmit,
                child: const Text('确认', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
