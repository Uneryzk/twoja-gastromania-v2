/// Mock clock so the deals calendar can be advanced from the dev switch.
abstract final class TGClock {
  static Duration offset = Duration.zero;

  static DateTime now() => DateTime.now().add(offset);

  static void reset() => offset = Duration.zero;

  static void advance(Duration d) => offset += d;
}
