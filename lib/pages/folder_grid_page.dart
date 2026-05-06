import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../update/update_service.dart';
import '../update/update_dialog.dart';
import '../db/database_helper.dart';
import '../models/folder.dart';
import '../models/word.dart';
import 'practice_history_page.dart';
import 'word_grid_page.dart';
import 'info_page.dart';
import 'about_page.dart';

class FolderGridPage extends StatefulWidget {
  final String? parentId;
  final String? title;

  const FolderGridPage({super.key, this.parentId, this.title});

  bool get isRoot => parentId == null;

  @override
  State<FolderGridPage> createState() => _FolderGridPageState();
}

class _FolderGridPageState extends State<FolderGridPage> {
  late Future<List<Folder>> _foldersFuture;
  String? _selectedFolderId;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  void _loadFolders() {
    _foldersFuture = DatabaseHelper.instance.getFoldersByParentId(
      widget.parentId,
    );
  }

  Future<void> _importData(BuildContext context) async {
    final status = await Permission.storage.request();

    if (status.isGranted || status.isLimited) {
      final sourceDirPath = await FilePicker.platform.getDirectoryPath();
      if (sourceDirPath == null) return;

      final sourceDir = Directory(sourceDirPath);
      if (!await sourceDir.exists()) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('所选文件夹不存在')));
        }
        return;
      }

      // 显示导入进度弹窗
      final progressNotifier = ValueNotifier<String>('正在复制文件...');
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 20),
                Expanded(
                  child: ValueListenableBuilder<String>(
                    valueListenable: progressNotifier,
                    builder: (context, text, _) => Text(text),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      try {
        // 1. 在应用 cache 下创建时间戳目录
        final tempDir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        final cacheDir = Directory(path.join(tempDir.path, timestamp));
        await cacheDir.create(recursive: true);

        // 2. 复制源文件夹下所有文件到 cache 目录
        progressNotifier.value = '正在复制文件...';
        final entities = await sourceDir.list().toList();
        for (final entity in entities) {
          if (entity is File) {
            final fileName = path.basename(entity.path);
            final destPath = path.join(cacheDir.path, fileName);
            await entity.copy(destPath);
          }
        }

        // 3. 查找 JSON 文件
        progressNotifier.value = '正在查找 JSON 文件...';
        final jsonFiles = await cacheDir
            .list()
            .where((e) => e is File && e.path.toLowerCase().endsWith('.json'))
            .cast<File>()
            .toList();

        if (jsonFiles.isEmpty) {
          progressNotifier.dispose();
          if (context.mounted) {
            Navigator.of(context).pop(); // 关闭进度弹窗
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('所选文件夹中没有找到 JSON 文件')));
          }
          return;
        }

        // 4. 读取并导入第一个 JSON
        progressNotifier.value = '正在导入数据...';
        final jsonFile = jsonFiles.first;
        final content = await jsonFile.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        await _importJsonToDatabase(json, cacheDir.path);

        progressNotifier.dispose();
        if (context.mounted) {
          Navigator.of(context).pop(); // 关闭进度弹窗
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('导入成功')));
        }
        setState(() {
          _loadFolders();
        });
      } catch (e) {
        progressNotifier.dispose();
        if (context.mounted) {
          Navigator.of(context).pop(); // 关闭进度弹窗
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('导入失败: $e')));
        }
      }
    } else if (status.isPermanentlyDenied) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('权限被拒绝'),
            content: const Text('存储权限被永久拒绝，无法导入文件。请前往设置开启权限。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  openAppSettings();
                  Navigator.pop(context);
                },
                child: const Text('去设置'),
              ),
            ],
          ),
        );
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('存储权限被拒绝，无法导入文件')));
      }
    }
  }

  Future<void> _importJsonToDatabase(
    Map<String, dynamic> json,
    String cacheDir,
  ) async {
    final db = DatabaseHelper.instance;
    final rootName = json['name'] as String? ?? '未命名';
    final categories = json['categories'] as List<dynamic>? ?? [];

    String? resolvePath(String? relativePath) {
      if (relativePath == null || relativePath.isEmpty) return null;
      if (path.isAbsolute(relativePath)) return relativePath;
      return path.join(cacheDir, relativePath);
    }

    final database = await db.database;
    await database.transaction((txn) async {
      // 1. 创建根目录（第一级），path 绑定 cache 时间戳目录
      final rootId = const Uuid().v4();
      final rootFolder = Folder(
        id: rootId,
        name: rootName,
        parentId: null,
        hasChild: categories.isNotEmpty,
        path: cacheDir,
      );
      await txn.insert('folder', rootFolder.toMap());

      // 2. 遍历 categories 作为二级目录
      for (final category in categories) {
        final categoryMap = category as Map<String, dynamic>;
        final categoryName = categoryMap['name'] as String? ?? '未命名';
        final terms = categoryMap['terms'] as List<dynamic>? ?? [];

        final categoryId = const Uuid().v4();
        final categoryFolder = Folder(
          id: categoryId,
          name: categoryName,
          parentId: rootId,
          hasChild: terms.isNotEmpty,
        );
        await txn.insert('folder', categoryFolder.toMap());

        // 3. 遍历 terms 作为单词（第三级）
        for (final term in terms) {
          final termMap = term as Map<String, dynamic>;
          final word = Word(
            foldId: categoryId,
            abbreviation: termMap['abbreviation'] as String?,
            learnWord: termMap['learn_word'] as String? ?? '',
            myWord: termMap['my_word'] as String? ?? '',
            description: termMap['description'] as String?,
            audio: resolvePath(termMap['audio'] as String?),
            image: resolvePath(termMap['image'] as String?),
          );
          await txn.insert('word', word.toMap());
        }
      }
    });
  }

  void _onFolderTap(Folder folder) {
    if (widget.isRoot) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              FolderGridPage(parentId: folder.id, title: folder.name),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WordGridPage(foldId: folder.id, title: folder.name),
        ),
      );
    }
  }

  Future<void> _editFolder(BuildContext context, Folder folder) async {
    final controller = TextEditingController(text: folder.name);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑目录'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: '目录名称'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    final newName = controller.text.trim();

    // 延迟 dispose，等待对话框退场动画完成
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });

    if (confirmed == true && newName.isNotEmpty) {
      try {
        final updated = Folder(
          id: folder.id,
          name: newName,
          parentId: folder.parentId,
          hasChild: folder.hasChild,
          path: folder.path,
        );
        await DatabaseHelper.instance.updateFolder(updated);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('修改成功')));
          setState(() {
            _loadFolders();
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('修改失败: $e')));
        }
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, Folder folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除「${folder.name}」及其所有单词和数据吗？此操作不可恢复。'),
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
        await DatabaseHelper.instance.deleteFolderCascade(folder.id);

        if (folder.path != null && folder.path!.isNotEmpty) {
          final dir = Directory(folder.path!);
          if (await dir.exists()) {
            await dir.delete(recursive: true);
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('删除成功')));
          setState(() {
            _loadFolders();
          });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.isRoot)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: '更多',
                onSelected: (value) {
                  switch (value) {
                    case 'info':
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const InfoPage()),
                      );
                      break;
                    case 'about':
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AboutPage()),
                      );
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'info', child: Text('说明')),
                  const PopupMenuItem(value: 'about', child: Text('关于')),
                ],
              ),
            Flexible(
              child: Text(
                widget.title ?? '疯码单词助手',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        actions: widget.isRoot
            ? [
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.history, size: 16),
                    label: const Text('练习记录', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PracticeHistoryPage(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withAlpha(50),
                      foregroundColor: Colors.white,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.file_upload_outlined, size: 16),
                    label: const Text('导入', style: TextStyle(fontSize: 12)),
                    onPressed: () => _importData(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withAlpha(50),
                      foregroundColor: Colors.white,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ]
            : null,
      ),
      body: FutureBuilder<List<Folder>>(
        future: _foldersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('加载失败: ${snapshot.error}'));
          }

          final folders = snapshot.data ?? [];

          if (folders.isEmpty) {
            return const Center(child: Text('暂无数据'));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: folders.length,
            itemBuilder: (context, index) {
              final folder = folders[index];
              final isSelected = _selectedFolderId == folder.id;

              return Stack(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (_selectedFolderId != null) {
                        setState(() => _selectedFolderId = null);
                      } else {
                        _onFolderTap(folder);
                      }
                    },
                    onLongPress: () {
                      setState(() => _selectedFolderId = folder.id);
                    },
                    child: Card(
                      elevation: 2,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            folder.name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (isSelected)
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedFolderId = null),
                        child: Container(
                          color: Colors.black.withAlpha(120),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() => _selectedFolderId = null);
                                    _editFolder(context, folder);
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
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() => _selectedFolderId = null);
                                    _confirmDelete(context, folder);
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
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
