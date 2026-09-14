import 'dart:async';

import 'package:flutter/material.dart';

import '../db/user_database.dart';
import '../models/word.dart';
import '../services/audio_service.dart';
import '../services/recording_service.dart';
import '../utils/resource_helper.dart';
import '../widgets/smart_image.dart';

/// 单词练习页
///
/// 三个练习模块：
/// 1. 听音：点击播放音频，累计10次
/// 2. 拼写：正确输入单词，累计10次
/// 3. 跟读：录音跟读，累计10次
///
/// 达标后仍可继续练习，完成状态在 Tab 标签右上角以绿勾显示。
class WordPracticePage extends StatefulWidget {
  final int taskId;
  final Word word;
  final int date;

  const WordPracticePage({
    super.key,
    required this.taskId,
    required this.word,
    required this.date,
  });

  @override
  State<WordPracticePage> createState() => _WordPracticePageState();
}

class _WordPracticePageState extends State<WordPracticePage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  int _audioCount = 0;
  int _spellCount = 0;
  int _readCount = 0;

  bool _isAudioPlaying = false;

  // 拼写相关
  final TextEditingController _spellController = TextEditingController();
  String? _spellFeedback;
  bool _isSubmitting = false;

  // 跟读相关
  bool _isRecording = false;
  String? _lastRecordingPath;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;
  Future<void>? _startFuture; // 追踪录音启动是否完成

  static const int _target = 10;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProgress();
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _tabController.dispose();
    _spellController.dispose();
    AudioService.instance.stop();
    RecordingService.instance.stopPlayback();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    final counts = await UserDatabase.instance.getWordPracticeCounts(
      widget.taskId,
      widget.word.id!,
      widget.date,
    );
    if (mounted) {
      setState(() {
        _audioCount = counts.audio;
        _spellCount = counts.spell;
        _readCount = counts.read;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.word.word, overflow: TextOverflow.ellipsis),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: Icon(Icons.volume_up,
                  color: _audioCount >= _target ? Colors.green : null),
              text: '听音 $_audioCount/$_target',
            ),
            Tab(
              icon: Icon(Icons.edit,
                  color: _spellCount >= _target ? Colors.green : null),
              text: '拼写 $_spellCount/$_target',
            ),
            Tab(
              icon: Icon(Icons.mic,
                  color: _readCount >= _target ? Colors.green : null),
              text: '跟读 $_readCount/$_target',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAudioTab(textColor),
          _buildSpellTab(textColor),
          _buildReadAloudTab(textColor),
        ],
      ),
    );
  }

  // ==================== 听音 Tab ====================

  Widget _buildAudioTab(Color textColor) {
    final imageUrl = ResourceHelper.resolveUrl(widget.word.pic);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (imageUrl != null && imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SmartImage(
                source: imageUrl,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
              ),
            ),
          if (imageUrl != null && imageUrl.isNotEmpty) const SizedBox(height: 16),
          Text(
            widget.word.word,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor),
          ),
          if (widget.word.phonetic != null && widget.word.phonetic!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                widget.word.phonetic!,
                style: TextStyle(fontSize: 16, color: textColor.withValues(alpha: 0.6)),
              ),
            ),
          const SizedBox(height: 40),
          GestureDetector(
            onTap: _isAudioPlaying ? null : _playAudio,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: (_isAudioPlaying ? Colors.grey : Colors.blue).withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isAudioPlaying ? Colors.grey : Colors.blue,
                  width: 2,
                ),
              ),
              child: Icon(
                _isAudioPlaying ? Icons.hourglass_top : Icons.volume_up,
                size: 56,
                color: _isAudioPlaying ? Colors.grey : Colors.blue,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _isAudioPlaying ? '播放中...' : '点击播放音频（$_audioCount/$_target）',
            style: TextStyle(fontSize: 14, color: textColor.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 24),
          if (_audioCount >= _target)
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                SizedBox(width: 4),
                Text('听音练习完成', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _playAudio() async {
    if (_isAudioPlaying) return;
    _isAudioPlaying = true;
    setState(() {});

    await AudioService.instance.play(widget.word.audio);
    // 等待播放完成，防止连续点击
    try {
      await AudioService.instance.onPlayerComplete.first.timeout(
        const Duration(seconds: 10),
      );
    } catch (_) {}

    if (!mounted) return;
    _isAudioPlaying = false;

    await UserDatabase.instance.insertPracticeLog(
      taskId: widget.taskId,
      wordId: widget.word.id!,
      word: widget.word.word,
      date: widget.date,
      practiceType: 1,
      isCorrect: true,
    );
    setState(() => _audioCount++);
  }

  // ==================== 拼写 Tab ====================

  Widget _buildSpellTab(Color textColor) {
    final imageUrl = ResourceHelper.resolveUrl(widget.word.pic);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          if (imageUrl != null && imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SmartImage(
                source: imageUrl,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
              ),
            ),
          if (imageUrl != null && imageUrl.isNotEmpty) const SizedBox(height: 16),
          // 提示：翻译
          if (widget.word.translation != null && widget.word.translation!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Text(
                widget.word.translation!,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
                textAlign: TextAlign.center,
              ),
            ),
          if (widget.word.phonetic != null && widget.word.phonetic!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                widget.word.phonetic!,
                style: TextStyle(fontSize: 14, color: textColor.withValues(alpha: 0.5)),
              ),
            ),
          const SizedBox(height: 32),
          TextField(
            controller: _spellController,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, color: textColor),
            decoration: InputDecoration(
              hintText: '请输入单词',
              hintStyle: TextStyle(color: textColor.withValues(alpha: 0.4)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onSubmitted: (_) => _submitSpell(),
          ),
          const SizedBox(height: 16),
          if (_spellFeedback != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                _spellFeedback!,
                style: TextStyle(
                  fontSize: 14,
                  color: _spellFeedback == '正确！' ? Colors.green : Colors.red,
                ),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitSpell,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('确认（$_spellCount/$_target）'),
            ),
          ),
          const SizedBox(height: 24),
          if (_spellCount >= _target)
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                SizedBox(width: 4),
                Text('拼写练习完成', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitSpell() async {
    if (_isSubmitting) return;
    final input = _spellController.text.trim().toLowerCase();
    if (input.isEmpty) return;

    _isSubmitting = true;
    try {
      final correctWord = widget.word.word.toLowerCase().trim();
      final isCorrect = input == correctWord;

      await UserDatabase.instance.insertPracticeLog(
        taskId: widget.taskId,
        wordId: widget.word.id!,
        word: widget.word.word,
        date: widget.date,
        practiceType: 2,
        isCorrect: isCorrect,
        content: input,
      );

      setState(() {
        if (isCorrect) {
          _spellCount++;
          _spellFeedback = '正确！';
          _spellController.clear();
        } else {
          _spellFeedback = '错误，正确答案: $correctWord';
        }
      });

      // 800ms后清除反馈
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _spellFeedback = null);
      });
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  // ==================== 跟读 Tab ====================

  Widget _buildReadAloudTab(Color textColor) {
    final imageUrl = ResourceHelper.resolveUrl(widget.word.pic);
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          if (imageUrl != null && imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SmartImage(
                source: imageUrl,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
              ),
            ),
          if (imageUrl != null && imageUrl.isNotEmpty) const SizedBox(height: 16),
          Text(
            widget.word.word,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor),
          ),
          if (widget.word.phonetic != null && widget.word.phonetic!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                widget.word.phonetic!,
                style: TextStyle(fontSize: 16, color: textColor.withValues(alpha: 0.6)),
              ),
            ),
          const SizedBox(height: 40),
          // 录音按钮（按下录音，松手停止，最长 5 秒）
          Listener(
            onPointerDown: (_) => _startRecording(),
            onPointerUp: (_) => _stopRecording(),
            onPointerCancel: (_) => _stopRecording(),
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: _isRecording
                    ? Colors.red.withValues(alpha: 0.15)
                    : Colors.purple.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isRecording ? Colors.red : Colors.purple,
                  width: 2,
                ),
              ),
              child: _isRecording
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${5 - _recordingSeconds}s',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const Text(
                          '松手停止',
                          style: TextStyle(fontSize: 12, color: Colors.red),
                        ),
                      ],
                    )
                  : const Icon(Icons.mic, size: 56, color: Colors.purple),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _isRecording
                ? '录音中 ${_recordingSeconds}s / 5s'
                : '长按开始录音（$_readCount/$_target）',
            style: TextStyle(fontSize: 14, color: textColor.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 24),
          // 播放原音和录音对比
          if (_readCount > 0 || _lastRecordingPath != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () => AudioService.instance.play(widget.word.audio),
                  icon: const Icon(Icons.volume_up, size: 20),
                  label: const Text('原音'),
                ),
                const SizedBox(width: 16),
                if (_lastRecordingPath != null)
                  TextButton.icon(
                    onPressed: () => RecordingService.instance.playLocalFile(_lastRecordingPath!),
                    icon: const Icon(Icons.play_arrow, size: 20),
                    label: const Text('我的录音'),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          if (_readCount >= _target)
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                SizedBox(width: 4),
                Text('跟读练习完成', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startRecording() async {
    if (_isRecording) return;

    // 立即进入录音状态（UI 即时反馈），不等录音器真正启动
    setState(() {
      _isRecording = true;
      _recordingSeconds = 0;
    });

    // 每秒更新计时
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _recordingSeconds++);
      // 最长 5 秒自动停止
      if (_recordingSeconds >= 5) {
        timer.cancel();
        _stopRecording();
      }
    });

    _startFuture = RecordingService.instance
        .startRecording(widget.taskId, widget.word.id!);
    try {
      await _startFuture;
    } catch (_) {
      // 启动失败，回滚录音状态
      if (mounted) {
        _recordingTimer?.cancel();
        _recordingTimer = null;
        setState(() => _isRecording = false);
      }
    } finally {
      _startFuture = null;
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    _recordingTimer?.cancel();
    _recordingTimer = null;

    // 若录音器还在启动中，等它启动完成再停止，避免竞态
    final pending = _startFuture;
    if (pending != null) {
      try {
        await pending;
      } catch (_) {}
    }

    final path = await RecordingService.instance.stopRecording();
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _recordingSeconds = 0;
    });

    if (path != null) {
      _lastRecordingPath = path;
      await UserDatabase.instance.insertPracticeLog(
        taskId: widget.taskId,
        wordId: widget.word.id!,
        word: widget.word.word,
        date: widget.date,
        practiceType: 3,
        isCorrect: true,
        content: path,
      );
      setState(() => _readCount++);
    }
  }

}
