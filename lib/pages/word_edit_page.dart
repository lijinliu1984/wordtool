import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../db/database_helper.dart';
import '../models/word.dart';

class WordEditPage extends StatefulWidget {
  final Word word;

  const WordEditPage({super.key, required this.word});

  @override
  State<WordEditPage> createState() => _WordEditPageState();
}

class _WordEditPageState extends State<WordEditPage> {
  late final TextEditingController _learnWordController;
  late final TextEditingController _myWordController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _abbreviationController;

  String? _imagePath;
  String? _audioPath;
  String? _cacheDir;

  @override
  void initState() {
    super.initState();
    _learnWordController = TextEditingController(text: widget.word.learnWord);
    _myWordController = TextEditingController(text: widget.word.myWord);
    _descriptionController = TextEditingController(
      text: widget.word.description ?? '',
    );
    _abbreviationController = TextEditingController(
      text: widget.word.abbreviation ?? '',
    );
    _imagePath = widget.word.image;
    _audioPath = widget.word.audio;
    _resolveCacheDir();
  }

  @override
  void dispose() {
    _learnWordController.dispose();
    _myWordController.dispose();
    _descriptionController.dispose();
    _abbreviationController.dispose();
    super.dispose();
  }

  Future<void> _resolveCacheDir() async {
    if (_imagePath != null && _imagePath!.isNotEmpty) {
      setState(() {
        _cacheDir = path.dirname(_imagePath!);
      });
      return;
    }
    if (_audioPath != null && _audioPath!.isNotEmpty) {
      setState(() {
        _cacheDir = path.dirname(_audioPath!);
      });
      return;
    }

    final folder = await DatabaseHelper.instance.getFolderById(
      widget.word.foldId,
    );
    if (folder?.parentId != null) {
      final rootFolder = await DatabaseHelper.instance.getFolderById(
        folder!.parentId!,
      );
      if (mounted) {
        setState(() {
          _cacheDir = rootFolder?.path;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _cacheDir = folder?.path;
        });
      }
    }
  }

  Future<void> _pickAndCropImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;

    final sourcePath = result.files.first.path!;
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      maxWidth: 150,
      maxHeight: 150,
      compressFormat: ImageCompressFormat.png,
    );

    if (croppedFile == null) return;

    final cacheDir = _cacheDir ?? (await getTemporaryDirectory()).path;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.png';
    final destPath = path.join(cacheDir, fileName);
    await File(croppedFile.path).copy(destPath);

    setState(() {
      _imagePath = destPath;
    });
  }

  Future<void> _pickAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;

    final sourcePath = result.files.first.path!;
    final cacheDir = _cacheDir ?? (await getTemporaryDirectory()).path;
    final fileName = path.basename(sourcePath);
    final destPath = path.join(cacheDir, fileName);
    await File(sourcePath).copy(destPath);

    setState(() {
      _audioPath = destPath;
    });
  }

  Future<void> _save() async {
    final updatedWord = widget.word.copyWith(
      learnWord: _learnWordController.text,
      myWord: _myWordController.text,
      description: _descriptionController.text.isEmpty
          ? null
          : _descriptionController.text,
      abbreviation: _abbreviationController.text.isEmpty
          ? null
          : _abbreviationController.text,
      image: _imagePath,
      audio: _audioPath,
    );

    await DatabaseHelper.instance.updateWord(updatedWord);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存成功')));
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('编辑单词'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 图片
            Center(
              child: GestureDetector(
                onTap: _pickAndCropImage,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _imagePath != null && _imagePath!.isNotEmpty
                      ? Image.file(
                          File(_imagePath!),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(
                                Icons.broken_image,
                                size: 50,
                                color: Colors.grey,
                              ),
                            );
                          },
                        )
                      : const Center(
                          child: Icon(
                            Icons.add_photo_alternate,
                            size: 50,
                            color: Colors.grey,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: _pickAndCropImage,
                icon: const Icon(Icons.crop),
                label: const Text('选择并裁剪图片'),
              ),
            ),
            const SizedBox(height: 24),

            // 音频
            Card(
              child: ListTile(
                leading: const Icon(Icons.audiotrack),
                title: Text(
                  _audioPath != null && _audioPath!.isNotEmpty
                      ? path.basename(_audioPath!)
                      : '未选择音频',
                ),
                trailing: TextButton(
                  onPressed: _pickAudio,
                  child: const Text('更换'),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 表单
            TextField(
              controller: _learnWordController,
              decoration: const InputDecoration(
                labelText: '学习词',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _myWordController,
              decoration: const InputDecoration(
                labelText: '母语词',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '描述',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _abbreviationController,
              decoration: const InputDecoration(
                labelText: '缩写',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
