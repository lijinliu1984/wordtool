import 'package:flutter/material.dart';

import '../db/user_database.dart';
import 'practice_history_page.dart';

/// 每日练习统计列表页
///
/// 按日期展示练习次数汇总，点击某天跳转 [PracticeHistoryPage] 查看当日详情。
class DailyPracticeListPage extends StatefulWidget {
  const DailyPracticeListPage({super.key});

  @override
  State<DailyPracticeListPage> createState() => _DailyPracticeListPageState();
}

class _DailyPracticeListPageState extends State<DailyPracticeListPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = UserDatabase.instance.getDailyPracticeStats();
  }

  void _refresh() {
    setState(() {
      _future = UserDatabase.instance.getDailyPracticeStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('练习记录'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('加载失败: ${snapshot.error}'));
          }

          final records = snapshot.data ?? [];
          if (records.isEmpty) {
            return const Center(child: Text('暂无练习记录'));
          }

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: records.length,
              itemBuilder: (context, index) {
                final row = records[index];
                final dayStr = row['day'] as String;
                final parts = dayStr.split('-');
                final date = DateTime(
                  int.parse(parts[0]),
                  int.parse(parts[1]),
                  int.parse(parts[2]),
                );
                final translation = row['translation_count'] as int? ?? 0;
                final listening = row['listening_count'] as int? ?? 0;
                final dictation = row['dictation_count'] as int? ?? 0;
                final totalWords = row['total_words'] as int? ?? 0;
                final correctWords = row['correct_words'] as int? ?? 0;
                final accuracy = totalWords > 0
                    ? (correctWords / totalWords * 100).round()
                    : 0;

                return Card(
                  elevation: 1,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PracticeHistoryPage(date: date),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${date.month}月${date.day}日 星期${_weekday(date.weekday)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: accuracy >= 80
                                      ? Colors.green.shade50
                                      : accuracy >= 60
                                          ? Colors.orange.shade50
                                          : Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '正确率 $accuracy%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: accuracy >= 80
                                        ? Colors.green
                                        : accuracy >= 60
                                            ? Colors.orange
                                            : Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _statChip(
                                Icons.translate,
                                '翻译',
                                translation,
                                const Color(0xFF5B8DEF),
                              ),
                              const SizedBox(width: 12),
                              _statChip(
                                Icons.headphones,
                                '听力',
                                listening,
                                const Color(0xFFFF6B9D),
                              ),
                              const SizedBox(width: 12),
                              _statChip(
                                Icons.edit_note,
                                '默写',
                                dictation,
                                const Color(0xFFFFB300),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '共 $totalWords 词 · 正确 $correctWords 词',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _statChip(IconData icon, String label, int count, Color color) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 4),
          Text(
            '$label $count',
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  String _weekday(int w) {
    const days = ['一', '二', '三', '四', '五', '六', '日'];
    return days[w - 1];
  }
}
