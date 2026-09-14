import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/server_config.dart';
import 'db/vocabulary_database.dart';
import 'pages/main_shell.dart';
import 'services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: WidgetsFlutterBinding.ensureInitialized());
  await ThemeService.instance.init();
  await ServerConfig.instance.init();

  // 首次启动：从 assets 复制词库到应用目录（不联网）
  await VocabularyDatabase.copyFromAssets();

  final prefs = await SharedPreferences.getInstance();
  final hasAgreed = prefs.getBool('has_agreed_disclaimer') ?? false;

  runApp(MyApp(initialShowDisclaimer: !hasAgreed));
  FlutterNativeSplash.remove();
}

class MyApp extends StatefulWidget {
  final bool initialShowDisclaimer;

  const MyApp({super.key, this.initialShowDisclaimer = false});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late bool _showDisclaimer;

  @override
  void initState() {
    super.initState();
    _showDisclaimer = widget.initialShowDisclaimer;
    ThemeService.instance.modeNotifier.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _agreeAndDismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_agreed_disclaimer', true);
    if (mounted) {
      setState(() {
        _showDisclaimer = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue),
      useMaterial3: true,
    );

    return MaterialApp(
      title: '疯码单词助手',
      theme: ThemeService.instance.applyTo(baseTheme),
      home: _showDisclaimer
          ? DisclaimerPage(onAgree: _agreeAndDismiss)
          : const MainShell(),
    );
  }
}

/// 开源声明弹窗页
class DisclaimerPage extends StatelessWidget {
  final VoidCallback onAgree;

  const DisclaimerPage({super.key, required this.onAgree});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline, size: 48, color: Colors.lightBlue),
                  const SizedBox(height: 16),
                  const Text(
                    '开源声明',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '本应用为开源软件，所有内置图片仅供测试调试使用。若涉及版权问题，请联系作者删除。',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onAgree,
                      child: const Text('同意并进入'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
