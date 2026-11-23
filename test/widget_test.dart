import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cunzhi/main.dart';

void main() {
  testWidgets('存知 App 启动并显示底部导航', (WidgetTester tester) async {
    await tester.pumpWidget(const CunzhiApp());

    // 等待一帧让 Provider 初始化
    await tester.pump();

    // 验证底部导航的两个 Tab 存在
    expect(find.text('全部'), findsWidgets);
    expect(find.text('分类'), findsWidgets);
  });
}
