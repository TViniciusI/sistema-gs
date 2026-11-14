class PwaInstall {
  static bool get isStandalone => false;
  static bool get canInstall => false;
  static bool get isIosGuide => false;
  static bool get shouldOffer => false;

  static Future<bool> prompt() async => false;
}
