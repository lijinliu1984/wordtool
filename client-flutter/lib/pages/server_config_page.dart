import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../config/server_config.dart';

/// 服务器地址编辑页
class ServerConfigPage extends StatefulWidget {
  const ServerConfigPage({super.key});

  @override
  State<ServerConfigPage> createState() => _ServerConfigPageState();
}

class _ServerConfigPageState extends State<ServerConfigPage> {
  late final TextEditingController _controller;
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  String? _testResult;
  bool _testSuccess = false;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ServerConfig.instance.baseUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final url = _controller.text.trim();
    if (url.isEmpty) {
      setState(() {
        _testResult = '请输入服务器地址';
        _testSuccess = false;
      });
      return;
    }

    setState(() {
      _testing = true;
      _testResult = null;
    });

    try {
      final base = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
      await _dio.get(
        '$base/api/version',
        queryParameters: {'version_code': 0},
      );
      setState(() {
        _testResult = '✓ 连接正常';
        _testSuccess = true;
      });
    } catch (_) {
      setState(() {
        _testResult = '✗ 无法连接到服务器';
        _testSuccess = false;
      });
    } finally {
      setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    final url = _controller.text.trim();
    if (url.isEmpty) return;
    await ServerConfig.instance.setBaseUrl(url);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('服务器地址已更新: ${ServerConfig.instance.baseUrl}')),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(title: const Text('服务器地址')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '修改服务器地址后所有接口请求将使用新地址。',
              style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: '服务器地址',
                hintText: 'https://wt.fmcode.top',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              autocorrect: false,
              onChanged: (_) {
                if (_testResult != null) setState(() => _testResult = null);
              },
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _testing ? null : _testConnection,
              icon: _testing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_find),
              label: Text(_testing ? '测试中...' : '测试连接'),
            ),
            const SizedBox(height: 12),
            if (_testResult != null)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                decoration: BoxDecoration(
                  color: _testSuccess
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _testResult!,
                  style: TextStyle(
                    color: _testSuccess ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
                    child: const Text('保存'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
