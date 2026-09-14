import 'package:flutter/material.dart';

import '../services/sync_service.dart';

/// 词库下载进度页（全屏，显示进度条和百分比）
class DownloadProgressPage extends StatefulWidget {
  final bool isUpdate;

  const DownloadProgressPage({super.key, this.isUpdate = true});

  @override
  State<DownloadProgressPage> createState() => _DownloadProgressPageState();
}

class _DownloadProgressPageState extends State<DownloadProgressPage> {
  double? _progress;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    try {
      await SyncService.instance.downloadDb(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 8),
                Text('更新成功'),
              ],
            ),
            content: const Text('词库已更新到最新版本。'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // 关闭弹窗
                  Navigator.pop(context); // 关闭下载页
                },
                child: const Text('确定'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('更新词库')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('下载失败', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('返回'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.isUpdate ? '更新词库' : '下载词库')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_download, size: 64, color: Colors.lightBlue),
            const SizedBox(height: 24),
            const Text('正在下载词库...', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: _progress != null
                  ? Column(
                      children: [
                        LinearProgressIndicator(value: _progress),
                        const SizedBox(height: 12),
                        Text('${(_progress! * 100).toStringAsFixed(0)}%'),
                      ],
                    )
                  : const CircularProgressIndicator(),
            ),
          ],
        ),
      ),
    );
  }
}
