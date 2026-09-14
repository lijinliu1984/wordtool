import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 显示模式
enum DisplayMode {
  light('默认', Icons.wb_sunny_outlined),
  eyeCare('护眼', Icons.visibility_outlined),
  eInk('墨水屏', Icons.menu_book_outlined),
  dark('夜间', Icons.nightlight_round);

  final String label;
  final IconData icon;

  const DisplayMode(this.label, this.icon);
}

/// 主题/显示模式服务
///
/// 持久化当前显示模式，并提供对应 ThemeData。
class ThemeService {
  ThemeService._();
  static final ThemeService instance = ThemeService._();

  static const _key = 'display_mode';

  DisplayMode _mode = DisplayMode.light;
  final ValueNotifier<DisplayMode> modeNotifier =
      ValueNotifier(DisplayMode.light);

  DisplayMode get mode => _mode;

  /// 初始化：从本地加载显示模式
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      _mode = DisplayMode.values.firstWhere(
        (e) => e.name == raw,
        orElse: () => DisplayMode.light,
      );
    }
  }

  /// 切换显示模式
  Future<void> setMode(DisplayMode mode) async {
    _mode = mode;
    modeNotifier.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  /// 将当前模式应用到 ThemeData
  ThemeData applyTo(ThemeData base) {
    return switch (_mode) {
      DisplayMode.light => _lightTheme(base),
      DisplayMode.eyeCare => _eyeCareTheme(base),
      DisplayMode.eInk => _eInkTheme(base),
      DisplayMode.dark => _darkTheme(base),
    };
  }

  ThemeData _lightTheme(ThemeData base) {
    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFFF7F8FA),
      cardTheme: base.cardTheme.copyWith(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF42A5F5),
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
    );
  }

  ThemeData _eyeCareTheme(ThemeData base) {
    const bg = Color(0xFFF5F0E6);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      cardTheme: base.cardTheme.copyWith(
        color: const Color(0xFFFAF6ED),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      colorScheme: base.colorScheme.copyWith(
        primary: const Color(0xFF8B7355),
        inversePrimary: const Color(0xFFD4C4A8),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFE8DCC8),
        foregroundColor: Color(0xFF5D4E37),
        titleTextStyle: TextStyle(
          color: Color(0xFF5D4E37),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: Color(0xFF5D4E37)),
      ),
    );
  }

  ThemeData _eInkTheme(ThemeData base) {
    return base.copyWith(
      scaffoldBackgroundColor: Colors.white,
      cardTheme: base.cardTheme.copyWith(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.black, width: 1.5),
        ),
      ),
      colorScheme: base.colorScheme.copyWith(
        primary: Colors.black,
        surface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        titleTextStyle: TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: Colors.black),
      ),
    );
  }

  ThemeData _darkTheme(ThemeData base) {
    const onSurface = Color(0xFFE0E0E0);
    const darkTextTheme = TextTheme(
      displayLarge: TextStyle(color: onSurface),
      displayMedium: TextStyle(color: onSurface),
      displaySmall: TextStyle(color: onSurface),
      headlineLarge: TextStyle(color: onSurface),
      headlineMedium: TextStyle(color: onSurface),
      headlineSmall: TextStyle(color: onSurface),
      titleLarge: TextStyle(color: onSurface),
      titleMedium: TextStyle(color: onSurface),
      titleSmall: TextStyle(color: onSurface),
      bodyLarge: TextStyle(color: onSurface),
      bodyMedium: TextStyle(color: onSurface),
      bodySmall: TextStyle(color: onSurface),
      labelLarge: TextStyle(color: onSurface),
      labelMedium: TextStyle(color: onSurface),
      labelSmall: TextStyle(color: onSurface),
    );
    return base.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF1A1A2E),
      cardTheme: base.cardTheme.copyWith(
        color: const Color(0xFF252542),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      textTheme: darkTextTheme,
      colorScheme: base.colorScheme.copyWith(
        brightness: Brightness.dark,
        surface: const Color(0xFF252542),
        onSurface: onSurface,
        onPrimary: onSurface,
        inversePrimary: const Color(0xFF2D2D4A),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E3A),
        foregroundColor: onSurface,
        titleTextStyle: TextStyle(
          color: onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: onSurface),
      ),
    );
  }
}
