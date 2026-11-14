import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

enum _Step { line, page, edge }

/// Rola a página visível com ↑ ↓ PageUp PageDown Home End no teclado
/// (notebook / desktop / web). Não interfere em campos de texto.
class KeyboardPageScroll extends StatefulWidget {
  const KeyboardPageScroll({super.key, required this.child});

  final Widget child;

  @override
  State<KeyboardPageScroll> createState() => _KeyboardPageScrollState();
}

class _KeyboardPageScrollState extends State<KeyboardPageScroll> {
  static const _line = 96.0;

  /// Última posição do mouse; sem ela, usa o meio da tela.
  Offset? _pointer;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  static final _steps = <LogicalKeyboardKey, (_Step, bool)>{
    LogicalKeyboardKey.arrowDown: (_Step.line, true),
    LogicalKeyboardKey.arrowUp: (_Step.line, false),
    LogicalKeyboardKey.pageDown: (_Step.page, true),
    LogicalKeyboardKey.pageUp: (_Step.page, false),
    LogicalKeyboardKey.end: (_Step.edge, true),
    LogicalKeyboardKey.home: (_Step.edge, false),
  };

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    final step = _steps[event.logicalKey];
    if (step == null || _isTyping()) return false;
    final (kind, forward) = step;

    final position = _visiblePosition(forward: forward);
    if (position == null) return false;

    final min = position.minScrollExtent;
    final max = position.maxScrollExtent;
    final sign = forward ? 1.0 : -1.0;
    final target = switch (kind) {
      _Step.line => position.pixels + sign * _line,
      _Step.page => position.pixels + sign * position.viewportDimension * 0.85,
      _Step.edge => forward ? max : min,
    }.clamp(min, max);
    if (target == position.pixels) return false;
    if (event is KeyRepeatEvent) {
      position.jumpTo(target);
    } else {
      position.animateTo(
        target,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
      );
    }
    return true;
  }

  bool _isTyping() {
    final focus = FocusManager.instance.primaryFocus;
    final ctx = focus?.context;
    if (ctx == null) return false;
    if (ctx.widget is EditableText) return true;
    return ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  /// Lista vertical que está de fato na tela (sob o mouse ou no meio),
  /// ignorando páginas por baixo da atual e abas escondidas.
  ScrollPosition? _visiblePosition({required bool forward}) {
    final byBox = <RenderObject, ScrollPosition>{};
    void visit(Element element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        final position = (element.state as ScrollableState).position;
        final box = element.findRenderObject();
        if (box != null &&
            position.axis == Axis.vertical &&
            position.hasContentDimensions &&
            position.maxScrollExtent > position.minScrollExtent) {
          byBox[box] = position;
        }
      }
      element.visitChildren(visit);
    }

    context.visitChildElements(visit);
    if (byBox.isEmpty) return null;

    final size = MediaQuery.sizeOf(context);
    final points = <Offset>[
      ?_pointer,
      Offset(size.width / 2, size.height / 2),
      Offset(size.width / 2, size.height * 0.75),
    ];
    final binding = WidgetsBinding.instance;
    final viewId = View.of(context).viewId;
    for (final point in points) {
      final result = HitTestResult();
      binding.hitTestInView(result, point, viewId);
      // Do mais interno para o mais externo: o primeiro que ainda anda vence.
      for (final entry in result.path) {
        final position = byBox[entry.target];
        if (position == null) continue;
        final canMove = forward
            ? position.pixels < position.maxScrollExtent
            : position.pixels > position.minScrollExtent;
        if (canMove) return position;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerHover: (e) => _pointer = e.position,
      onPointerDown: (e) => _pointer = e.position,
      onPointerSignal: (e) {
        if (e is PointerScrollEvent) _pointer = e.position;
      },
      child: widget.child,
    );
  }
}

/// Atalhos só fazem sentido com teclado físico (web / desktop).
bool get keyboardPageScrollEnabled =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.linux;
