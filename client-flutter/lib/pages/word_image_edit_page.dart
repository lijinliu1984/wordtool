import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../db/user_database.dart';
import '../db/vocabulary_database.dart';
import '../models/word.dart';
import '../services/word_image_service.dart';
import '../utils/resource_helper.dart';
import '../widgets/smart_image.dart';

/// 单词图片更换页
///
/// 展示原图，点击"新图片"区域底部弹窗选择相册/拍照，裁剪为 64x64 后预览，
/// 确认上传到服务器并同步更新本地词库与任务表。
class WordImageEditPage extends StatefulWidget {
  final Word word;

  const WordImageEditPage({super.key, required this.word});

  @override
  State<WordImageEditPage> createState() => _WordImageEditPageState();
}

class _WordImageEditPageState extends State<WordImageEditPage> {
  Uint8List? _processedBytes;
  String? _error;
  bool _uploading = false;

  /// 底部弹窗选相册/拍照，选定后裁剪为 64x64
  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('拍照'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final XFile? picked;
    try {
      picked = await ImagePicker()
          .pickImage(source: source, maxWidth: 512, maxHeight: 512);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('选择图片失败: $e')));
      }
      return;
    }
    if (picked == null || !mounted) return;

    await _processImage(picked);
  }

  /// 读取选中图片并裁剪为 64x64（已经是 64x64 则直接使用）
  Future<void> _processImage(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        throw Exception('无法解析图片');
      }
      final img.Image processed;
      if (decoded.width == 64 && decoded.height == 64) {
        processed = decoded;
      } else {
        processed = img.copyResizeCropSquare(decoded, size: 64);
      }
      final out = img.encodePng(processed);
      if (!mounted) return;
      setState(() {
        _processedBytes = Uint8List.fromList(out);
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _upload() async {
    final wordId = widget.word.id;
    final bytes = _processedBytes;
    if (wordId == null || bytes == null) return;

    setState(() => _uploading = true);
    try {
      final newPic = await WordImageService.instance.uploadImage(wordId, bytes);
      await VocabularyDatabase.instance.updateWordPic(wordId, newPic);
      await UserDatabase.instance.updateTaskWordPic(wordId, newPic);
      if (!mounted) return;
      Navigator.pop(context, newPic);
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('上传失败: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final originalUrl = ResourceHelper.resolveUrl(widget.word.pic);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('更换图片'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      widget.word.learnWord,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.word.myWord,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('当前图片', style: TextStyle(color: Colors.grey[700])),
            const SizedBox(height: 8),
            Center(
              child: SmartImage(
                source: originalUrl,
                width: 96,
                height: 96,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 24),
            Text('新图片（点击选择）', style: TextStyle(color: Colors.grey[700])),
            const SizedBox(height: 8),
            Center(child: _buildNewImageArea()),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _uploading ? null : () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_uploading || _processedBytes == null)
                        ? null
                        : _upload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B9D),
                    ),
                    child: _uploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('确认上传',
                            style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewImageArea() {
    if (_error != null) {
      return Text('图片处理失败: $_error',
          style: const TextStyle(color: Colors.red));
    }
    return GestureDetector(
      onTap: _uploading ? null : _pickImage,
      child: Container(
        width: 128,
        height: 128,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(8),
        ),
        child: _processedBytes == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      size: 32, color: Colors.grey[500]),
                  const SizedBox(height: 4),
                  Text('点击选择图片',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  _processedBytes!,
                  width: 128,
                  height: 128,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              ),
      ),
    );
  }
}
