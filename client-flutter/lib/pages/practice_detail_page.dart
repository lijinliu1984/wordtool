import 'package:flutter/material.dart';

import '../db/user_database.dart';

class PracticeDetailPage extends StatefulWidget {
  final int resultId;
  final String type;

  const PracticeDetailPage({
    super.key,
    required this.resultId,
    required this.type,
  });

  @override
  State<PracticeDetailPage> createState() => _PracticeDetailPageState();
}

class _PracticeDetailPageState extends State<PracticeDetailPage> {
  @override
  Widget build(BuildContext context) {
    final typeLabel = switch (widget.type) {
      'translation' => '翻译练习',
      'listening' || 'listening_image' || 'listening_text' => '听力练习',
      'dictation' => '默写练习',
      _ => '练习',
    };

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(
          '$typeLabel - 答题详情',
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _loadDetails(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('加载失败: ${snapshot.error}'));
          }

          final details = snapshot.data ?? [];

          if (details.isEmpty) {
            return const Center(child: Text('暂无明细数据'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: details.length,
            itemBuilder: (context, index) {
              final detail = details[index];
              final isCorrect = (detail['is_correct'] as int) == 1;
              final wordText = detail['word'] as String?;

              return Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isCorrect
                        ? Colors.green.shade200
                        : Colors.red.shade200,
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: isCorrect ? Colors.green : Colors.red,
                        child: Icon(
                          isCorrect ? Icons.check : Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '第 ${index + 1} 题',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (wordText != null) ...[
                              Text(
                                wordText,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ] else
                              Text(
                                '单词信息缺失',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        isCorrect ? '正确' : '错误',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isCorrect ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadDetails() async {
    final details = await UserDatabase.instance.getPracticeDetails(
      widget.resultId,
    );
    return details
        .map((detail) => <String, dynamic>{
              'word': detail['word'],
              'is_correct': detail['is_correct'],
            })
        .toList();
  }
}
