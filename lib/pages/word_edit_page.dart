import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../db/database_helper.dart';
import '../models/word.dart';
import '../utils/resource_helper.dart';
import '../widgets/smart_image.dart';

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
  late final TextEditingController _imageUrlController;
  late final TextEditingController _audioUrlController;

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

    final image = widget.word.image;
    if (ResourceHelper.isUrl(image)) {
      _imageUrlController = TextEditingController(text: image);
      _imagePath = null;
    } else {
      _imageUrlController = TextEditingController();
      _imagePath = image;
    }

    final audio = widget.word.audio;
    if (ResourceHelper.isUrl(audio)) {
      _audioUrlController = TextEditingController(text: audio);
      _audioPath = null;
    } else {
      _audioUrlController = TextEditingController();
      _audioPath = audio;
    }

    _resolveCacheDir();
  }

  @override
  void dispose() {
    _learnWordController.dispose();
    _myWordController.dispose();
    _descriptionController.dispose();
    _abbreviationController.dispose();
    _imageUrlController.dispose();
    _audioUrlController.dispose();
    super.dispose();
  }

  String? get _effectiveImage => _imageUrlController.text.trim().isNotEmpty
      ? _imageUrlController.text.trim()
      : _imagePath;

  String? get _effectiveAudio => _audioUrlController.text.trim().isNotEmpty
      ? _audioUrlController.text.trim()
      : _audioPath;

  String get _audioLabel {
    final url = _audioUrlController.text.trim();
    if (url.isNotEmpty) return url;
    if (_audioPath != null && _audioPath!.isNotEmpty) {
      return ResourceHelper.isUrl(_audioPath!)
          ? _audioPath!
          : path.basename(_audioPath!);
    }
    return '未选择音频';
  }

  Future<void> _resolveCacheDir() async {
    String? localPath;
    if (_imagePath != null &&
        _imagePath!.isNotEmpty &&
        !ResourceHelper.isUrl(_imagePath)) {
      localPath = _imagePath;
    } else if (_audioPath != null &&
        _audioPath!.isNotEmpty &&
        !ResourceHelper.isUrl(_audioPath)) {
      localPath = _audioPath;
    }

    if (localPath != null) {
      setState(() {
        _cacheDir = path.dirname(localPath!);
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
      _imageUrlController.clear();
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
      _audioUrlController.clear();
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
      image: _effectiveImage,
      audio: _effectiveAudio,
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
                  child: SmartImage(
                    source: _effectiveImage,
                    fit: BoxFit.cover,
                    defaultIcon: Icons.add_photo_alternate,
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
            const SizedBox(height: 4),
            TextField(
              controller: _imageUrlController,
              decoration: const InputDecoration(
                labelText: '或输入图片URL',
                hintText: 'https://...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),

            // 音频
            Card(
              child: ListTile(
                leading: const Icon(Icons.audiotrack),
                title: Text(_audioLabel),
                trailing: TextButton(
                  onPressed: _pickAudio,
                  child: const Text('更换'),
                ),
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _audioUrlController,
              decoration: const InputDecoration(
                labelText: '或输入音频URL',
                hintText: 'https://...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
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
