import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

import '../db/database_helper.dart';
import '../models/word.dart';
import '../utils/resource_helper.dart';
import '../widgets/smart_image.dart';
import 'word_edit_page.dart';
import 'translation_practice_page.dart';
import 'listening_practice_page.dart';
import 'practice_history_page.dart';
import 'dictation_practice_page.dart';

class WordGridPage extends StatefulWidget {
  final String foldId;
  final String? title;

  const WordGridPage({super.key, required this.foldId, this.title});

  @override
  State<WordGridPage> createState() => _WordGridPageState();
}

class _WordGridPageState extends State<WordGridPage> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ValueNotifier<int?> _playingWordId = ValueNotifier(null);
  final ValueNotifier<int?> _editingWordId = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerComplete.listen((_) {
      _playingWordId.value = null;
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _playingWordId.dispose();
    _editingWordId.dispose();
    super.dispose();
  }

  Future<List<Word>> _loadWords(String foldId) async {
    return DatabaseHelper.instance.getWordsByFolderId(foldId);
  }

  Future<void> _playAudio(String source, int wordId) async {
    try {
      await _audioPlayer.stop();
      _playingWordId.value = wordId;
      final src = ResourceHelper.isUrl(source)
          ? UrlSource(source)
          : DeviceFileSource(source);
      await _audioPlayer.play(src);
    } catch (e) {
      debugPrint('播放失败: $e');
      _playingWordId.value = null;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('音频播放失败: $e')));
      }
    }
  }

  Future<void> _deleteWord(BuildContext context, Word word) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除单词「${word.learnWord}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DatabaseHelper.instance.deleteWord(word.id!);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('删除成功')));
          setState(() {});
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('删除失败: $e')));
        }
      }
    }
  }

  Future<void> _editWord(BuildContext context, Word word) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => WordEditPage(word: word)),
    );

    if (result == true && mounted) {
      setState(() {});
    }
  }

  Future<void> _showPracticeMenu(BuildContext context) async {
    final words = await _loadWords(widget.foldId);
    if (words.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('当前目录没有单词数据')));
      }
      return;
    }

    if (!context.mounted) return;

    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          '请选择练习模式：',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                leading: const Icon(
                  Icons.translate,
                  color: Colors.blue,
                  size: 20,
                ),
                title: const Text('翻译练习', style: TextStyle(fontSize: 14)),
                subtitle: const Text('看词选译文', style: TextStyle(fontSize: 12)),
                onTap: () => Navigator.pop(context, 'translation'),
              ),
              ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                leading: const Icon(Icons.image, color: Colors.green, size: 20),
                title: const Text('听力练习A', style: TextStyle(fontSize: 14)),
                subtitle: const Text('听音频选图片', style: TextStyle(fontSize: 12)),
                onTap: () => Navigator.pop(context, 'listening_image'),
              ),
              ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                leading: const Icon(
                  Icons.translate,
                  color: Colors.teal,
                  size: 20,
                ),
                title: const Text('听力练习B', style: TextStyle(fontSize: 14)),
                subtitle: const Text('听音频选译文', style: TextStyle(fontSize: 12)),
                onTap: () => Navigator.pop(context, 'listening_text'),
              ),
              ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                leading: const Icon(
                  Icons.edit_note,
                  color: Colors.orange,
                  size: 20,
                ),
                title: const Text('默写练习A', style: TextStyle(fontSize: 14)),
                subtitle: const Text('听音频输入单词', style: TextStyle(fontSize: 12)),
                onTap: () => Navigator.pop(context, 'dictation_audio'),
              ),
              ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                leading: const Icon(
                  Icons.image_search,
                  color: Colors.pink,
                  size: 20,
                ),
                title: const Text('默写练习B', style: TextStyle(fontSize: 14)),
                subtitle: const Text('看图片输入单词', style: TextStyle(fontSize: 12)),
                onTap: () => Navigator.pop(context, 'dictation_image'),
              ),
              ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                leading: const Icon(
                  Icons.translate,
                  color: Colors.indigo,
                  size: 20,
                ),
                title: const Text('默写练习C', style: TextStyle(fontSize: 14)),
                subtitle: const Text('看译文输入单词', style: TextStyle(fontSize: 12)),
                onTap: () => Navigator.pop(context, 'dictation_text'),
              ),
            ],
          ),
        ),
      ),
    );

    if (!context.mounted) return;

    if (choice == 'translation') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TranslationPracticePage(words: words),
        ),
      );
    } else if (choice == 'listening_image') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ListeningPracticePage(words: words, mode: 'image'),
        ),
      );
    } else if (choice == 'listening_text') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ListeningPracticePage(words: words, mode: 'text'),
        ),
      );
    } else if (choice == 'dictation_audio') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DictationPracticePage(words: words, mode: 'audio'),
        ),
      );
    } else if (choice == 'dictation_image') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DictationPracticePage(words: words, mode: 'image'),
        ),
      );
    } else if (choice == 'dictation_text') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DictationPracticePage(words: words, mode: 'text'),
        ),
      );
    } else if (choice == 'history') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PracticeHistoryPage()),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(
          widget.title ?? '单词列表',
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        actions: [
          ElevatedButton(
            onPressed: () => _showPracticeMenu(context),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.deepPurple,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('练习'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<List<Word>>(
        future: _loadWords(widget.foldId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('加载失败: ${snapshot.error}'));
          }

          final words = snapshot.data ?? [];

          if (words.isEmpty) {
            return const Center(child: Text('暂无数据'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: words.length,
            itemBuilder: (context, index) {
              final word = words[index];
              final hasAudio = ResourceHelper.sourceExists(word.audio);
              final hasImage = ResourceHelper.sourceExists(word.image);

              debugPrint(
                'Word[${word.id}] learnWord=${word.learnWord}, '
                'audio=${word.audio}, image=${word.image}',
              );

              return GestureDetector(
                onTap: () {
                  if (_editingWordId.value != null) {
                    _editingWordId.value = null;
                  } else if (hasAudio) {
                    _playAudio(word.audio!, word.id!);
                  }
                },
                onLongPress: () => _editingWordId.value = word.id,
                child: Card(
                  elevation: 1,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (hasImage)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: SizedBox(
                                  width: 72,
                                  height: 72,
                                  child: SmartImage(
                                    source: word.image,
                                    width: 72,
                                    height: 72,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 72,
                                    memCacheHeight: 72,
                                  ),
                                ),
                              ),
                            if (hasImage) const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 72,
                                child: Stack(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(right: 52),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            word.abbreviation != null &&
                                                    word
                                                        .abbreviation!
                                                        .isNotEmpty
                                                ? '${word.abbreviation} · ${word.learnWord}'
                                                : word.learnWord,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            word.myWord,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[700],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (word.description != null &&
                                              word.description!.isNotEmpty)
                                            Text(
                                              word.description!,
                                              style: TextStyle(
                                                fontSize: 9,
                                                color: Colors.grey[600],
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (hasAudio)
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: ValueListenableBuilder<int?>(
                                          valueListenable: _playingWordId,
                                          builder: (context, playingId, child) {
                                            final isPlaying =
                                                playingId == word.id;
                                            return GestureDetector(
                                              onTap: () => _playAudio(
                                                word.audio!,
                                                word.id!,
                                              ),
                                              onLongPress: () {},
                                              child: AnimatedScale(
                                                scale: isPlaying ? 1.35 : 1.0,
                                                duration: const Duration(
                                                  milliseconds: 200,
                                                ),
                                                child: Icon(
                                                  Icons.volume_up,
                                                  size: 20,
                                                  color: isPlaying
                                                      ? Colors.green
                                                      : Colors.blue,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ValueListenableBuilder<int?>(
                        valueListenable: _editingWordId,
                        builder: (context, editingId, child) {
                          final isEditing = editingId == word.id;
                          if (!isEditing) return const SizedBox.shrink();
                          return Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: GestureDetector(
                                onTap: () => _editingWordId.value = null,
                                child: Container(
                                  color: Colors.black.withAlpha(120),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            _editingWordId.value = null;
                                            _editWord(context, word);
                                          },
                                          icon: const Icon(
                                            Icons.edit,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                          label: const Text(
                                            '编辑',
                                            style: TextStyle(fontSize: 11),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue,
                                            foregroundColor: Colors.white,
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 4,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            _editingWordId.value = null;
                                            _deleteWord(context, word);
                                          },
                                          icon: const Icon(
                                            Icons.delete,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                          label: const Text(
                                            '删除',
                                            style: TextStyle(fontSize: 11),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 4,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
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
}
