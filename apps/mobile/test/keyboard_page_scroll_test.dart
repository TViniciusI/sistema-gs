import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gs_mobile/core/keyboard_page_scroll.dart';

Widget _longList(ScrollController controller, String prefix) => ListView(
      controller: controller,
      children: [
        for (var i = 0; i < 80; i++)
          SizedBox(height: 60, child: Text('$prefix $i')),
      ],
    );

void main() {
  testWidgets('seta rola a página da frente, não a de baixo', (tester) async {
    final below = ScrollController();
    final front = ScrollController();
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navKey,
        builder: (context, child) => KeyboardPageScroll(child: child!),
        home: Scaffold(body: _longList(below, 'Lista')),
      ),
    );
    navKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(body: _longList(front, 'OS')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(front.offset, greaterThan(0));
    expect(below.offset, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pumpAndSettle();
    expect(front.offset, front.position.maxScrollExtent);

    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pumpAndSettle();
    expect(front.offset, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pumpAndSettle();
    expect(front.offset, greaterThan(300));
    expect(below.offset, 0);
  });

  testWidgets('seta não rola enquanto digita', (tester) async {
    final controller = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => KeyboardPageScroll(child: child!),
        home: Scaffold(
          body: Column(
            children: [
              const TextField(key: Key('campo')),
              Expanded(child: _longList(controller, 'Item')),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('campo')));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
  });
}
