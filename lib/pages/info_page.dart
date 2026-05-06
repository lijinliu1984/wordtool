import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InfoPage extends StatelessWidget {
  const InfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('说明'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '疯码单词助手',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '本软件完全开源免费，仅供个人学习、研究使用，禁止商用。',
              style: TextStyle(fontSize: 15, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            const Text(
              '项目采用 Flutter 开发，支持 Android、iOS、Windows、macOS、Linux 和 Web。'
              '采用"目录 → 分类 → 单词"三级结构管理词库，内置翻译、听力、默写等多种练习模式。'
              '数据基于 SQLite 本地存储，无需联网。',
              style: TextStyle(fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                const Text(
                  'AI 生成词库提示词',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _aiPrompt));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('提示词已复制到剪贴板')),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('复制'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SelectableText(
                _aiPrompt,
                style: const TextStyle(fontSize: 13, height: 1.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _aiPrompt =
      '帮我整理 30 个常用的德语单词，并生成 JSON 格式数据，JSON 格式内容如下：\n'
      '```json\n'
      '{\n'
      '  "name": "德语基础词汇",\n'
      '  "version": "1.0",\n'
      '  "categories": [\n'
      '    {\n'
      '      "id": "daily",\n'
      '      "name": "日常生活",\n'
      '      "terms": [\n'
      '        {\n'
      '          "abbreviation": "",\n'
      '          "learn_word": "Haus",\n'
      '          "my_word": "房子",\n'
      '          "description": "名词，中性",\n'
      '          "audio": "haus_de.mp3",\n'
      '          "image": "haus.png"\n'
      '        }\n'
      '      ]\n'
      '    }\n'
      '  ]\n'
      '}\n'
      '```\n'
      '其中 audio 和 image 不要空值，用英文命名。';
}
