import 'dart:js_interop';

@JS('gsForceHardReload')
external void _forceHardReload();

class AppReload {
  static void hardReload() {
    try {
      _forceHardReload();
    } catch (_) {}
  }
}
