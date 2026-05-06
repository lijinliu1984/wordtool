import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('关于'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部
            const Center(
              child: Column(
                children: [
                  Text(
                    '疯码单词助手',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF45B7D1),
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '免费背单词，轻松学外语',
                    style: TextStyle(fontSize: 15, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 应用简介
            _buildCard(
              title: '应用简介',
              child: const Text(
                '疯码单词助手是一款开源的跨平台背单词应用，专为语言学习者设计。'
                '通过"目录 → 分类 → 单词"三级结构管理词库，'
                '结合图片、音频等多媒体资源，提供翻译、听力、默写等多种练习模式，'
                '帮助用户高效记忆单词。支持一键导入 JSON 词库，可借助 AI 快速生成学习内容。',
                style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.6),
              ),
            ),

            // 主要功能
            _buildCard(
              title: '主要功能',
              child: Column(
                children: [
                  _buildFeature('目录九宫格导航，三级词库管理'),
                  _buildFeature('单词支持关联音频和图片'),
                  _buildFeature('批量导入 JSON + 媒体文件夹'),
                  _buildFeature('翻译练习、听力练习（听音选图/选词）'),
                  _buildFeature('默写练习（听音/看图/看译文 输入单词）'),
                  _buildFeature('练习记录自动保存，支持历史回顾'),
                  _buildFeature('数据本地存储，无需联网'),
                ],
              ),
            ),

            // 开发者信息
            _buildCard(
              title: '开发者信息',
              child: Column(
                children: [
                  _buildInfoRow('开发团队', '江西省萍乡市湘东区疯码信息工作室'),
                  const SizedBox(height: 14),
                  _buildInfoRow('联系邮箱', '19170910300@163.com'),
                ],
              ),
            ),

            // 素材来源
            _buildCard(
              title: '素材来源',
              child: Column(
                children: [
                  _buildLinkRow(
                    label: '音频合成',
                    text: 'ttsmaker',
                    url: 'https://ttsmaker.cn/',
                  ),
                  const SizedBox(height: 14),
                  _buildLinkRow(
                    label: '图片生成',
                    text: '即梦AI',
                    url: 'https://jimeng.jianying.com/',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildCard({
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.only(left: 10),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: Color(0xFF45B7D1), width: 3),
              ),
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  static Widget _buildFeature(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('● ', style: TextStyle(fontSize: 12, color: Color(0xFF45B7D1))),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 15, color: Colors.black87)),
      ],
    );
  }

  static Widget _buildLinkRow({
    required String label,
    required String text,
    required String url,
  }) {
    return InkWell(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 4),
                Text(
                  '$text ↗',
                  style: const TextStyle(fontSize: 15, color: Color(0xFF45B7D1)),
                ),
              ],
            ),
          ),
          const Icon(Icons.open_in_new, size: 14, color: Colors.grey),
        ],
      ),
    );
  }
}
