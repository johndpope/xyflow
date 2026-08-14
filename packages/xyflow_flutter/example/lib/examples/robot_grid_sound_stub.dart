/// No-op sound effects on non-web platforms.
abstract final class RobotGridSound {
  static bool enabled = true;

  static void playConnect() {}

  static void playBounce(double intensity) {}

  static void playCut() {}

  static void playSpawn() {}

  static void playPickup() {}

  static void playDrop() {}

  static void playThrow(double intensity) {}
}
