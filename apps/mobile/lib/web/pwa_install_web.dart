import 'dart:js_interop';

@JS('gsPwaCanInstall')
external JSBoolean _canInstall();

@JS('gsPwaIsIos')
external JSBoolean _isIos();

@JS('gsPwaIsStandalone')
external JSBoolean _isStandalone();

@JS('gsPwaInstall')
external JSPromise<JSBoolean> _install();

class PwaInstall {
  static bool get isStandalone => _isStandalone().toDart;
  static bool get canInstall => _canInstall().toDart;
  static bool get isIosGuide => _isIos().toDart;
  static bool get shouldOffer => !isStandalone && (canInstall || isIosGuide);

  static Future<bool> prompt() async {
    final result = await _install().toDart;
    return result.toDart;
  }
}
