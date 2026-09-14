import 'package:flutter/material.dart';

import '../db/user_database.dart';
import '../db/vocabulary_database.dart';
import '../models/category.dart';
import '../models/level.dart';
import '../models/word_filter.dart';
import 'category_list_page.dart';
import 'word_grid_page.dart';

/// 单词广场
class WordSquarePage extends StatefulWidget {
  const WordSquarePage({super.key});

  @override
  State<WordSquarePage> createState() => _WordSquarePageState();
}

class _WordSquarePageState extends State<WordSquarePage> {
  int _totalWords = 0;
  List<Level> _levels = [];
  List<Category> _categories = [];
  Map<int, int> _learnedWords = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      _totalWords = await VocabularyDatabase.instance.getTotalWordCount();
      _levels = await VocabularyDatabase.instance.getLevels();
      _categories = await VocabularyDatabase.instance.getCategories();
      _categories.sort((a, b) => b.wordCount.compareTo(a.wordCount));
      _learnedWords = await _loadLearnedWords();
    } catch (e) {
      debugPrint('单词广场加载失败: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<Map<int, int>> _loadLearnedWords() async {
    final db = await UserDatabase.instance.database;
    final result = await db.rawQuery('''
      SELECT pd.word
      FROM practice_detail pd
      JOIN practice_result pr ON pd.result_id = pr.id
      WHERE pd.is_correct = 1
    ''');
    final words = result.map((r) => r['word'] as String).toSet();

    final map = <int, int>{};
    for (final level in _levels) {
      final levelWords = await VocabularyDatabase.instance.getWords(
        WordFilter(level: level.level),
      );
      map[level.level] = levelWords.where((w) => words.contains(w.word)).length;
    }
    return map;
  }

  void _openWordList({int? level, int? categoryId, String? title}) {
    final filter = WordFilter(level: level, categoryId: categoryId);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WordGridPage(
          filter: filter,
          title: title ?? filter.toString(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 20),
                      _buildTotalCard(),
                      const SizedBox(height: 24),
                      _buildHotCategories(),
                      const SizedBox(height: 24),
                      _buildLevelList(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          '单词广场',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.search, color: Colors.grey[700]),
        ),
      ],
    );
  }

  Widget _buildTotalCard() {
    return GestureDetector(
      onTap: () => _openWordList(title: '全部单词'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF6B9D), Color(0xFF6B8CFF)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '单词总量',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatNumber(_totalWords),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Text(
                        '查看全部',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward,
                        color: Colors.white.withValues(alpha: 0.9),
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHotCategories() {
    final hotItems = _categories.take(4).toList();
    final colors = [
      const Color(0xFFFFE4EC),
      const Color(0xFFE8F0FE),
      const Color(0xFFFFF8E1),
      const Color(0xFFE3F2FD),
    ];
    final iconColors = [
      const Color(0xFFFF6B9D),
      const Color(0xFF5B8DEF),
      const Color(0xFFFFB300),
      const Color(0xFF42A5F5),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '热门分类',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CategoryListPage()),
              ),
              child: const Text('查看更多'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: hotItems.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = hotItems[index];
              return GestureDetector(
                onTap: () => _openWordList(
                  categoryId: item.id,
                  title: item.cnName,
                ),
                child: Container(
                  width: 90,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors[index % colors.length],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: iconColors[index % iconColors.length],
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            item.pic ?? '📦',
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.cnName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.wordCount}词',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLevelList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '按 Level 学习',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Text(
              '共 ${_levels.length} 个 Level',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._levels.asMap().entries.map((entry) {
          final index = entry.key;
          final level = entry.value;
          return _buildLevelCard(level, index);
        }),
      ],
    );
  }

  Widget _buildLevelCard(Level level, int index) {
    final learned = _learnedWords[level.level] ?? 0;
    final isCompleted = learned >= level.wordCount && level.wordCount > 0;
    final colors = [
      const Color(0xFFFFE4EC),
      const Color(0xFFE8F0FE),
      const Color(0xFFFFF8E1),
      const Color(0xFFE3F2FD),
    ];
    final iconColors = [
      const Color(0xFFFF6B9D),
      const Color(0xFF5B8DEF),
      const Color(0xFFFFB300),
      const Color(0xFF42A5F5),
    ];
    final icons = [
      Icons.star,
      Icons.trending_up,
      Icons.school,
      Icons.emoji_events,
    ];

    return GestureDetector(
      onTap: () => _openWordList(level: level.level, title: level.name),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color ?? Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colors[index % colors.length],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icons[index % icons.length],
                color: iconColors[index % iconColors.length],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Level ${level.level} · ${level.name}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${level.wordCount} 词 · 已掌握 $learned 词',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isCompleted
                    ? const Color(0xFFE8F5E9)
                    : const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isCompleted ? '已学完' : '进行中',
                style: TextStyle(
                  fontSize: 12,
                  color: isCompleted
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFFF6B9D),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }


  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );
  }
}
