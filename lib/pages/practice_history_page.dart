import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import 'practice_detail_page.dart';

class PracticeHistoryPage extends StatefulWidget {
  const PracticeHistoryPage({super.key});

  @override
  State<PracticeHistoryPage> createState() => _PracticeHistoryPageState();
}

class _PracticeHistoryPageState extends State<PracticeHistoryPage> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: const Text('练习记录'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '翻译练习', icon: Icon(Icons.translate)),
              Tab(text: '听力练习', icon: Icon(Icons.headphones)),
              Tab(text: '默写练习', icon: Icon(Icons.edit_note)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildList('translation'),
            _buildList('listening'),
            _buildList('dictation'),
          ],
        ),
      ),
    );
  }

  Widget _buildList(String type) {
    final future = type == 'listening'
        ? DatabaseHelper.instance.getPracticeResultsByTypes([
            'listening',
            'listening_image',
            'listening_text',
          ])
        : DatabaseHelper.instance.getPracticeResults(type);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('加载失败: ${snapshot.error}'));
        }

        final records = snapshot.data ?? [];

        if (records.isEmpty) {
          return const Center(child: Text('暂无记录'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: records.length,
          itemBuilder: (context, index) {
            final record = records[index];
            final totalCount = record['total_count'] as int;
            final correctCount = record['correct_count'] as int;
            final createdAt = DateTime.fromMillisecondsSinceEpoch(
              record['created_at'] as int,
            );
            final accuracy = totalCount > 0
                ? (correctCount / totalCount * 100).round()
                : 0;

            final resultId = record['id'] as int;

            return Card(
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PracticeDetailPage(resultId: resultId, type: type),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: accuracy >= 80
                            ? Colors.green
                            : accuracy >= 60
                            ? Colors.orange
                            : Colors.red,
                        child: Text(
                          '$accuracy%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '正确 $correctCount / $totalCount 题',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${createdAt.year}-${_pad(createdAt.month)}-${_pad(createdAt.day)} '
                              '${_pad(createdAt.hour)}:${_pad(createdAt.minute)}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: Colors.grey,
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _pad(int value) => value.toString().padLeft(2, '0');
}
