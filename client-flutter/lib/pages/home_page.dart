import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../db/user_database.dart';
import '../db/vocabulary_database.dart';
import '../models/task.dart';
import '../services/sync_service.dart';
import '../services/theme_service.dart';
import 'daily_practice_list_page.dart';
import 'download_progress_page.dart';
import 'full_test_page.dart';
import 'server_config_page.dart';
import 'task_detail_page.dart';
import 'task_edit_page.dart';
import 'task_list_page.dart';
import 'task_word_list_page.dart';
import 'today_word_list_page.dart';

/// 首页
class HomePage extends StatefulWidget {
  static final GlobalKey<HomePageState> globalKey = GlobalKey();

  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  Task? _task;
  int _taskLearned = 0;
  int _todayTarget = 0;
  int _todayPracticed = 0;
  bool _todayTestPassed = false;
  ({int total, int correct}) _todayStats = (total: 0, correct: 0);
  ({int translation, int listening, int dictation}) _todayPracticeCounts =
      (translation: 0, listening: 0, dictation: 0);
  Map<String, int> _weeklyStats = {};
  ({
    int checkInDays,
    int practiceWords,
    int testWords,
    double accuracy,
  }) _monthlyStats = (
    checkInDays: 0,
    practiceWords: 0,
    testWords: 0,
    accuracy: 0,
  );
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _checkVocabularyUpdate();
    _requestPermissions();
  }

  /// 检查并申请应用所需的基础权限（录音/相机/相册）
  Future<void> _requestPermissions() async {
    final permissions = [
      Permission.microphone,
      Permission.camera,
      Permission.photos,
    ];
    for (final permission in permissions) {
      if (!await permission.isGranted) {
        await permission.request();
      }
    }
  }

  /// 检查词库更新
  /// [showToastIfLatest] 为 true 时，若已是最新则弹出 SnackBar 提示
  Future<void> _checkVocabularyUpdate({bool showToastIfLatest = false}) async {
    final versionInfo = await VocabularyDatabase.instance.getVersionInfo();
    if (versionInfo == null || !mounted) return;

    final updateData =
        await SyncService.instance.checkUpdate(versionInfo.versionCode);
    if (updateData == null || !mounted) {
      if (showToastIfLatest && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前单词库已经是最新的了')),
        );
      }
      return;
    }

    await _showUpdateDialog(updateData, versionInfo);
  }

  /// 清除缓存的图片和音频文件
  Future<void> _clearCache() async {
    try {
      // 清除网络图片磁盘缓存（CachedNetworkImage 默认用 DefaultCacheManager）
      await DefaultCacheManager().emptyCache();
      // 清除框架层内存中的图片位图缓存
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      // 清除跟读录音文件
      final dir = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory(dir.path + '/recordings');
      if (await recordingsDir.exists()) {
        await recordingsDir.delete(recursive: true);
        await recordingsDir.create(recursive: true);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('缓存已清除')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('清除缓存失败')),
        );
      }
    }
  }

  Future<void> _showUpdateDialog(
    Map<String, dynamic> updateData,
    ({int versionCode, String versionName}) currentVersion,
  ) async {
    final shouldUpdate = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('词库更新 ${updateData['version_name']}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '更新日期: ${updateData['update_date']}',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const Divider(height: 24),
              Text(
                updateData['title'] as String,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Text(updateData['update_content'] as String),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '当前: ${currentVersion.versionName}  →  最新: ${updateData['version_name']}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('跳过'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('立即更新'),
          ),
        ],
      ),
    );

    if (shouldUpdate == true && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DownloadProgressPage(isUpdate: true)),
      );
    }
  }

  Future<void> _loadData() async {
    try {
      _task = await UserDatabase.instance.getActiveTask();
      if (_task != null) {
        _taskLearned = await UserDatabase.instance.getTaskLearnedWordCount(_task!);
        _todayTarget = await UserDatabase.instance.getTodayTargetWordCount(_task!.id!);
        _todayPracticed = await UserDatabase.instance.getTodayPracticedCount(_task!.id!);
        _todayTestPassed = await UserDatabase.instance.isTodayTestPassed(_task!.id!);
      }
      _todayStats = await UserDatabase.instance.getTodayStats();
      _todayPracticeCounts =
          await UserDatabase.instance.getTodayPracticeCounts();
      _weeklyStats = await UserDatabase.instance.getWeeklyStats();
      _monthlyStats = await UserDatabase.instance.getMonthlyStats();
    } catch (e) {
      debugPrint('首页加载失败: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return '早上好，小词友 👋';
    if (hour < 18) return '下午好，小词友 👋';
    return '晚上好，小词友 👋';
  }

  /// 公开刷新入口：底部 tab 切到首页时调用
  void refresh() {
    _loadData();
    _requestPermissions();
  }

  String get _todayLabel {
    final now = DateTime.now();
    final weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return '${now.month}月${now.day}日 星期${weekdays[now.weekday - 1]}';
  }

  Future<void> _openTaskEdit() async {
    if (_task != null) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TaskDetailPage(task: _task!)),
      );
      if (result == true) _loadData();
    } else {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TaskEditPage(task: _task)),
      );
      if (result == true) _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 20),
                      _buildDisplayModeCard(),
                      const SizedBox(height: 16),
                      _buildTaskCard(),
                      if (_task != null) ...[
                        const SizedBox(height: 16),
                        _buildTodayProgressCard(),
                        const SizedBox(height: 16),
                        _buildTodayPracticeCard(),
                        const SizedBox(height: 16),
                        _buildWeeklyChart(),
                        const SizedBox(height: 16),
                        _buildMonthlySummary(),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    final textColor = Theme.of(context).colorScheme.onSurface;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _greeting,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
            ),
            const SizedBox(height: 4),
            Text(
              _todayLabel,
              style: TextStyle(fontSize: 14, color: textColor.withValues(alpha: 0.6)),
            ),
          ],
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.settings_outlined, color: textColor.withValues(alpha: 0.6)),
          offset: const Offset(0, 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (value) {
            if (value == 'server') {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ServerConfigPage()));
            }
            if (value == 'update') _checkVocabularyUpdate(showToastIfLatest: true);
            if (value == 'clear_cache') _clearCache();
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(
              value: 'server',
              child: ListTile(
                leading: Icon(Icons.dns_outlined),
                title: Text('服务器地址'),
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const PopupMenuItem(
              value: 'update',
              child: ListTile(
                leading: Icon(Icons.system_update_outlined),
                title: Text('单词库更新'),
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const PopupMenuItem(
              value: 'clear_cache',
              child: ListTile(
                leading: Icon(Icons.cleaning_services_outlined),
                title: Text('清除缓存'),
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDisplayModeCard() {
    return _card(
      bgColor: const Color(0xFF5B8DEF).withValues(alpha: 0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '显示模式',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: DisplayMode.values.map((mode) {
              final isSelected = ThemeService.instance.mode == mode;
              return GestureDetector(
                onTap: () => ThemeService.instance.setMode(mode),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFE8F0FE)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(color: const Color(0xFF5B8DEF), width: 1.5)
                            : null,
                      ),
                      child: Icon(
                        mode.icon,
                        color: isSelected
                            ? const Color(0xFF5B8DEF)
                            : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      mode.label,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected
                            ? const Color(0xFF5B8DEF)
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _navigateToPracticeList() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DailyPracticeListPage()),
    );
  }

  Widget _moreButton(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '更多',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            SizedBox(width: 2),
            Icon(Icons.chevron_right, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard() {
    if (_task == null) {
      return _card(
        bgColor: const Color(0xFFFFB300).withValues(alpha: 0.1),
        child: InkWell(
          onTap: _openTaskEdit,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Icon(Icons.add_circle_outline,
                    size: 48, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text(
                  '创建任务',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  '制定一个学习目标，开始背单词吧',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final progress = _task!.totalWords == 0
        ? 0.0
        : (_taskLearned / _task!.totalWords).clamp(0.0, 1.0);

    return _card(
      bgColor: const Color(0xFFFFB300).withValues(alpha: 0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '当前任务: ${_task!.name}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              _moreButton(() async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TaskListPage()),
                );
                if (result == true && mounted) _loadData();
              }),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => TaskWordListPage(task: _task!)),
              );
              if (result == true && mounted) _loadData();
            },
            borderRadius: BorderRadius.circular(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 进度条：百分比在右上方
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 10,
                        backgroundColor: Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation(Color(0xFFFF6B9D)),
                      ),
                    ),
                    Positioned(
                      right: 4,
                      top: -2,
                      child: Text(
                        '${(progress * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF6B9D),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildTaskStatusBadge(_task!),
                    Text(
                      '已背 $_taskLearned/${_task!.totalWords} 词',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    Text(
                      '截止 ${_task!.deadline.month}月${_task!.deadline.day}日',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskStatusBadge(Task task) {
    String label;
    Color bg;
    Color fg;
    if (task.isCompleted) {
      label = '已完成';
      bg = const Color(0xFFE8F5E9);
      fg = const Color(0xFF4CAF50);
    } else if (task.isActive && DateTime.now().isAfter(task.deadline)) {
      label = '延期';
      bg = const Color(0xFFFFEBEE);
      fg = const Color(0xFFF44336);
    } else {
      label = '进行中';
      bg = const Color(0xFFE3F2FD);
      fg = const Color(0xFF5B8DEF);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: fg,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTodayPracticeCard() {
    final total = _todayPracticeCounts.translation +
        _todayPracticeCounts.listening +
        _todayPracticeCounts.dictation;

    return _card(
      bgColor: const Color(0xFF4CAF50).withValues(alpha: 0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '今日练习记录',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              _moreButton(_navigateToPracticeList),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _practiceStatItem(
                Icons.translate,
                '翻译',
                _todayPracticeCounts.translation,
                const Color(0xFF5B8DEF),
              ),
              _practiceStatItem(
                Icons.headphones,
                '听力',
                _todayPracticeCounts.listening,
                const Color(0xFFFF6B9D),
              ),
              _practiceStatItem(
                Icons.edit_note,
                '默写',
                _todayPracticeCounts.dictation,
                const Color(0xFFFFB300),
              ),
              _practiceStatItem(
                Icons.check_circle_outline,
                '合计',
                total,
                const Color(0xFF4CAF50),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _practiceStatItem(
      IconData icon, String label, int count, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildTodayProgressCard() {
    final target = _todayTarget > 0 ? _todayTarget : (_task?.dailyGoal ?? 20);
    final current = _todayPracticed;
    final accuracy = _todayStats.total == 0
        ? 0
        : ((_todayStats.correct / _todayStats.total) * 100).toInt();

    // 判断当前阶段
    final allPracticed = _todayPracticed >= target && target > 0;
    final buttonLabel = _todayTestPassed
        ? '复习'
        : (allPracticed ? '开始测试' : '开始练习');
    final buttonColor = _todayTestPassed
        ? const Color(0xFFFFB300)
        : (allPracticed ? const Color(0xFF5B8DEF) : const Color(0xFFFF6B9D));
    final buttonIcon = _todayTestPassed
        ? Icons.refresh
        : (allPracticed ? Icons.fact_check : Icons.edit);
    final buttonAction = _todayTestPassed
        ? _startReview
        : (allPracticed ? _startTest : _startPractice);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFF6B9D).withValues(alpha: 0.1),
            const Color(0xFF6B8CFF).withValues(alpha: 0.1),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '今日学习进度',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              _progressButton(buttonLabel, buttonIcon, buttonColor, buttonAction),
            ],
          ),
          const SizedBox(height: 16),
          // 进度数字 + 操作按钮
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$current',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '/$target 词',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.4),
              valueColor: AlwaysStoppedAnimation(buttonColor),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTodayMetric('$accuracy%', '正确率'),
              _buildTodayMetric('25分', '学习时长'),
              _buildTodayMetric('$_todayPracticed', '已练习'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _progressButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startPractice() {
    if (_task == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TodayWordListPage(taskId: _task!.id!)),
    ).then((_) => _loadData());
  }

  Future<void> _startTest() async {
    await _startFullTest('test');
  }

  Future<void> _startReview() async {
    await _startFullTest('review');
  }

  Future<void> _startFullTest(String mode) async {
    if (_task == null) return;
    final words = await UserDatabase.instance.getTodayTaskWords(_task!.id!);
    if (words.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('当前任务下没有单词')));
      }
      return;
    }
    final optionPool = await UserDatabase.instance.getTestOptionPool(_task!.id!);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullTestPage(
          words: words,
          optionPool: optionPool,
          taskId: _task!.id!,
          practiceMode: mode,
        ),
      ),
    );
    if (mounted) _loadData();
  }

  Widget _buildTodayMetric(String value, String label) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: textColor.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyChart() {
    final keys = _weeklyStats.keys.toList();
    final maxValue = _weeklyStats.values.isEmpty
        ? 1
        : _weeklyStats.values.reduce((a, b) => a > b ? a : b);

    return _card(
      bgColor: const Color(0xFF26A69A).withValues(alpha: 0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '本周学习',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: keys.map((day) {
                final value = _weeklyStats[day] ?? 0;
                final ratio = maxValue == 0 ? 0 : value / maxValue;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 24,
                      height: (80 * ratio).toDouble(),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B9D),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      day,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlySummary() {
    return _card(
      bgColor: const Color(0xFF9C27B0).withValues(alpha: 0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '${''}月度总结',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryItem('${_monthlyStats.checkInDays}', '打卡天数'),
              _summaryItem('${_monthlyStats.practiceWords}', '练习单词'),
              _summaryItem('${_monthlyStats.testWords}', '测试单词'),
              _summaryItem(
                '${(_monthlyStats.accuracy * 100).toInt()}%',
                '正确率',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String value, String label) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.6)),
        ),
      ],
    );
  }

  Widget _card({required Widget child, Color? bgColor}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor ?? (Theme.of(context).cardTheme.color ?? Colors.white),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
