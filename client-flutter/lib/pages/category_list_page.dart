import 'package:flutter/material.dart';

import '../db/vocabulary_database.dart';
import '../models/category.dart';
import '../models/word_filter.dart';
import 'word_grid_page.dart';

/// 全部分类列表页
class CategoryListPage extends StatefulWidget {
  const CategoryListPage({super.key});

  @override
  State<CategoryListPage> createState() => _CategoryListPageState();
}

class _CategoryListPageState extends State<CategoryListPage> {
  List<Category> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final list = await VocabularyDatabase.instance.getCategories();
      list.sort((a, b) => b.wordCount.compareTo(a.wordCount));
      _categories = list;
    } catch (e) {
      debugPrint('加载分类列表失败: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openCategory(Category category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WordGridPage(
          filter: WordFilter(categoryId: category.id),
          title: category.cnName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('全部分类'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.8,
                ),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  return GestureDetector(
                    onTap: () => _openCategory(category),
                    child: Container(
                      padding: EdgeInsets.zero,
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color ?? Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            category.pic ?? '📦',
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              category.cnName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '${category.wordCount} 词',
                            style: TextStyle(
                              fontSize: 10,
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
    );
  }
}
