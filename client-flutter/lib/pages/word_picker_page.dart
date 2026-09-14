import 'package:flutter/material.dart';

import '../db/user_database.dart';
import '../db/vocabulary_database.dart';
import '../models/category.dart';
import '../models/level.dart';
import '../models/word.dart';
import '../models/word_filter.dart';

/// 单词选择页面（多选）
///
/// [selectedIds] 已选中的单词 ID 集合，进入时预先勾选。
/// [taskId] 当前正在编辑的任务 ID，用于排除其他任务已选单词。
/// 返回 `List<Word>` —— 本次新增选中的单词（不含取消的）。
class WordPickerPage extends StatefulWidget {
  final Set<int> selectedIds;
  final int? taskId;

  const WordPickerPage({super.key, required this.selectedIds, this.taskId});

  @override
  State<WordPickerPage> createState() => _WordPickerPageState();
}

class _WordPickerPageState extends State<WordPickerPage> {
  final _searchController = TextEditingController();
  final Set<int> _checked = {};
  final Map<int, Word> _wordMap = {};
  bool _isLoading = true;
  String _searchText = '';
  int _page = 0;
  static const _pageSize = 100;
  bool _hasMore = true;

  // 筛选条件
  List<Level> _levels = [];
  List<Category> _categories = [];
  Level? _selectedLevel;
  Category? _selectedCategory;
  Set<int> _assignedWordIds = {};

  @override
  void initState() {
    super.initState();
    _checked.addAll(widget.selectedIds);
    _loadFilters();
    _loadAssignedWords();
    _loadPage();
  }

  Future<void> _loadFilters() async {
    final levels = await VocabularyDatabase.instance.getLevels();
    final categories = await VocabularyDatabase.instance.getCategories();
    if (mounted) {
      setState(() {
        _levels = levels;
        _categories = categories;
      });
    }
  }

  Future<void> _loadAssignedWords() async {
    final ids = await UserDatabase.instance.getAllAssignedWordIds(
      excludeTaskId: widget.taskId,
    );
    if (mounted) {
      setState(() => _assignedWordIds = ids);
    }
  }

  void _onFilterChanged() {
    setState(() {
      _page = 0;
      _hasMore = true;
      _wordMap.clear();
    });
    _loadPage();
  }

  Future<void> _loadPage({bool refresh = false}) async {
    if (refresh) {
      _page = 0;
      _hasMore = true;
      _wordMap.clear();
    }
    if (!_hasMore) return;

    try {
      final filter = WordFilter(
        level: _selectedLevel?.level,
        categoryId: _selectedCategory?.id,
      );
      final words = await VocabularyDatabase.instance.getWords(
        filter,
        limit: _pageSize,
        offset: _page * _pageSize,
      );
      if (words.length < _pageSize) _hasMore = false;
      for (final w in words) {
        if (w.id != null) _wordMap[w.id!] = w;
      }
      _page++;
    } catch (e) {
      debugPrint('加载单词失败: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearch(String text) {
    setState(() {
      _searchText = text.toLowerCase();
    });
  }

  List<Word> get _filteredWords {
    var words = _wordMap.values.toList();
    // 排除其他任务已选的单词（但保留当前已选的）
    words = words.where((w) {
      final id = w.id ?? 0;
      return !_assignedWordIds.contains(id) || widget.selectedIds.contains(id);
    }).toList();
    // 搜索筛选
    if (_searchText.isNotEmpty) {
      words = words.where((w) {
        return w.word.toLowerCase().contains(_searchText) ||
            (w.translation?.toLowerCase().contains(_searchText) ?? false);
      }).toList();
    }
    return words;
  }

  void _toggle(int wordId) {
    setState(() {
      if (_checked.contains(wordId)) {
        _checked.remove(wordId);
      } else {
        _checked.add(wordId);
      }
    });
  }

  bool _isAllChecked(List<Word> words) {
    if (words.isEmpty) return false;
    return words.every((w) => _checked.contains(w.id ?? 0));
  }

  void _toggleAll() {
    final words = _filteredWords;
    setState(() {
      if (_isAllChecked(words)) {
        // 取消全选：只取消当前列表中的单词
        for (final w in words) {
          _checked.remove(w.id ?? 0);
        }
      } else {
        // 全选：选中当前列表中的所有单词
        for (final w in words) {
          _checked.add(w.id ?? 0);
        }
      }
    });
  }

  void _confirm() {
    final newWords = <Word>[];
    for (final id in _checked) {
      if (!widget.selectedIds.contains(id) && _wordMap.containsKey(id)) {
        newWords.add(_wordMap[id]!);
      }
    }
    Navigator.pop(context, newWords);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final words = _filteredWords;

    return Scaffold(
      appBar: AppBar(
        title: const Text('选择单词'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // 筛选下拉框
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<Level?>(
                    value: _selectedLevel,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: '学段',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: [
                      const DropdownMenuItem<Level?>(value: null, child: Text('全部学段', overflow: TextOverflow.ellipsis)),
                      ..._levels.map((l) => DropdownMenuItem<Level?>(
                        value: l,
                        child: Text('${l.name} (${l.wordCount}词)', overflow: TextOverflow.ellipsis),
                      )),
                    ],
                    onChanged: (v) {
                      setState(() => _selectedLevel = v);
                      _onFilterChanged();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<Category?>(
                    value: _selectedCategory,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: '分类',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: [
                      const DropdownMenuItem<Category?>(value: null, child: Text('全部分类', overflow: TextOverflow.ellipsis)),
                      ..._categories.map((c) => DropdownMenuItem<Category?>(
                        value: c,
                        child: Text(c.cnName, overflow: TextOverflow.ellipsis),
                      )),
                    ],
                    onChanged: (v) {
                      setState(() => _selectedCategory = v);
                      _onFilterChanged();
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索单词或翻译...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
                suffixIcon: _searchText.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearch('');
                        },
                      )
                    : null,
              ),
              onChanged: _onSearch,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '共 ${words.length} 词',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: _toggleAll,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isAllChecked(words)
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                            size: 18,
                            color: const Color(0xFFFF6B9D),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '全选',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '已选 ${_checked.length} 词',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFFF6B9D),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : words.isEmpty
                    ? const Center(child: Text('无匹配单词'))
                    : NotificationListener<ScrollNotification>(
                        onNotification: (scroll) {
                          if (scroll.metrics.pixels >=
                                  scroll.metrics.maxScrollExtent - 200 &&
                              _hasMore &&
                              !_isLoading) {
                            _loadPage();
                          }
                          return false;
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: words.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == words.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                    child: CircularProgressIndicator()),
                              );
                            }
                            final word = words[index];
                            final wordId = word.id ?? 0;
                            final isChecked = _checked.contains(wordId);

                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: isChecked
                                      ? const Color(0xFFFF6B9D)
                                      : Colors.grey.shade200,
                                  width: isChecked ? 1.5 : 1,
                                ),
                              ),
                              child: InkWell(
                                onTap: () => _toggle(wordId),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isChecked
                                            ? Icons.check_circle
                                            : Icons.circle_outlined,
                                        color: isChecked
                                            ? const Color(0xFFFF6B9D)
                                            : Colors.grey[400],
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              word.word,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (word.translation != null)
                                              Text(
                                                word.translation!,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey[600],
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (word.phonetic != null)
                                        Text(
                                          word.phonetic!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _checked.length > widget.selectedIds.length
                      ? _confirm
                      : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: const Color(0xFFFF6B9D),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    '确认添加 ${_checked.length - widget.selectedIds.length} 个单词',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
