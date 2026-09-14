import 'package:flutter/material.dart';

import '../db/user_database.dart';
import '../models/word.dart';
import '../utils/resource_helper.dart';
import '../widgets/smart_image.dart';
import 'word_practice_page.dart';

/// 今日单词列表页
///
/// 展示今日子任务的单词列表，每词显示三项练习进度（听音/拼写/跟读）。
/// 点击单词进入 [WordPracticePage] 进行逐词练习。
class TodayWordListPage extends StatefulWidget {
  final int taskId;

  const TodayWordListPage({super.key, required this.taskId});

  @override
  State<TodayWordListPage> createState() => _TodayWordListPageState();
}

class _TodayWordListPageState extends State<TodayWordListPage> {
  List<Map<String, dynamic>> _words = [];
  bool _isLoading = true;
  int _practicedCount = 0;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final words = await UserDatabase.instance.getTodayWordsWithProgress(widget.taskId);
      final practiced = words.where((w) => (w['is_practiced'] as int) == 1).length;
      if (mounted) {
        setState(() {
          _words = words;
          _practicedCount = practiced;
          _totalCount = words.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('今日单词'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _words.isEmpty
              ? Center(
                  child: Text(
                    '今日没有单词',
                    style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                  ),
                )
              : Column(
                  children: [
                    _buildProgressHeader(),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          itemCount: _words.length,
                          itemBuilder: (context, index) => _buildWordCard(index),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildProgressHeader() {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final allDone = _practicedCount == _totalCount && _totalCount > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (allDone ? Colors.green : const Color(0xFFFF6B9D))
            .withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            '练习进度 $_practicedCount/$_totalCount',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _totalCount > 0 ? _practicedCount / _totalCount : 0,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.4),
              valueColor: AlwaysStoppedAnimation(
                allDone ? Colors.green : const Color(0xFFFF6B9D),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            allDone ? '全部练习完成，可以开始测试了' : '点击单词开始练习（听音+拼写+跟读各10次）',
            style: TextStyle(
              fontSize: 13,
              color: textColor.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordCard(int index) {
    final row = _words[index];
    final word = Word(
      id: row['word_id'] as int,
      word: row['word'] as String,
      translation: row['translation'] as String?,
      phonetic: row['phonetic'] as String?,
      pic: row['pic'] as String?,
      audio: row['audio'] as String?,
    );
    final date = row['date'] as int;
    final isPracticed = (row['is_practiced'] as int) == 1;
    final audioCount = (row['audio_count'] as int?) ?? 0;
    final spellCount = (row['spell_count'] as int?) ?? 0;
    final readCount = (row['read_count'] as int?) ?? 0;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isPracticed
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WordPracticePage(
                taskId: widget.taskId,
                word: word,
                date: date,
              ),
            ),
          );
          _loadData();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 序号
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isPracticed
                      ? Colors.green.withValues(alpha: 0.15)
                      : const Color(0xFFFF6B9D).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isPracticed
                      ? const Icon(Icons.check, size: 18, color: Colors.green)
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isPracticed
                                ? Colors.green
                                : const Color(0xFFFF6B9D),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // 单词图片
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SmartImage(
                  source: ResourceHelper.resolveUrl(word.pic),
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  defaultIcon: Icons.image_outlined,
                ),
              ),
              const SizedBox(width: 12),
              // 单词信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      word.word,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (word.translation != null && word.translation!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          word.translation!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              // 三项进度
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _progressChip(Icons.volume_up, audioCount, Colors.blue),
                  const SizedBox(height: 4),
                  _progressChip(Icons.edit, spellCount, Colors.orange),
                  const SizedBox(height: 4),
                  _progressChip(Icons.mic, readCount, Colors.purple),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _progressChip(IconData icon, int count, Color color) {
    final done = count >= 10;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: done ? Colors.green : color),
        const SizedBox(width: 4),
        Text(
          '$count/10',
          style: TextStyle(
            fontSize: 11,
            color: done ? Colors.green : color,
            fontWeight: done ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
