import 'package:flutter/material.dart';

import 'practice_detail_page.dart';

class PracticeResultPage extends StatelessWidget {
  final String type;
  final int totalCount;
  final int correctCount;
  final int resultId;

  const PracticeResultPage({
    super.key,
    required this.type,
    required this.totalCount,
    required this.correctCount,
    required this.resultId,
  });

  String get _typeLabel {
    return switch (type) {
      'translation' => '翻译练习',
      'listening' || 'listening_image' || 'listening_text' => '听力练习',
      'dictation' => '默写练习',
      _ => '练习',
    };
  }

  String _encourageText(int accuracy) {
    if (accuracy == 100) {
      return '完美！全部答对，太厉害了！🎉';
    } else if (accuracy >= 90) {
      return '非常出色！继续保持！👏';
    } else if (accuracy >= 80) {
      return '表现很棒！再接再厉！💪';
    } else if (accuracy >= 60) {
      return '还不错，继续加油，你可以做得更好！📚';
    } else if (accuracy >= 40) {
      return '别灰心，多加练习，一定能进步！🌱';
    } else {
      return '不要气馁，熟能生巧，继续加油！🔥';
    }
  }

  @override
  Widget build(BuildContext context) {
    final accuracy = totalCount > 0
        ? (correctCount / totalCount * 100).round()
        : 0;
    final color = accuracy >= 80
        ? Colors.green
        : accuracy >= 60
        ? Colors.orange
        : Colors.red;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('测试结果'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text(
              _typeLabel,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            CircleAvatar(
              radius: 70,
              backgroundColor: color.withAlpha(30),
              child: CircleAvatar(
                radius: 60,
                backgroundColor: color,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$accuracy%',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '$correctCount/$totalCount',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              _encourageText(accuracy),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PracticeDetailPage(resultId: resultId, type: type),
                    ),
                  );
                },
                icon: const Icon(Icons.visibility),
                label: const Text('详情'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('完成'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
