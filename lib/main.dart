import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/app_state.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CunzhiApp());
}

class CunzhiApp extends StatelessWidget {
  const CunzhiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..load(),
      child: MaterialApp(
        title: '存知',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        // 禁用系统默认的页面切换动画时长，使用更轻快的过渡
        themeAnimationDuration: const Duration(milliseconds: 200),
        themeAnimationCurve: Curves.easeOut,
        home: const HomeScreen(),
      ),
    );
  }
}
