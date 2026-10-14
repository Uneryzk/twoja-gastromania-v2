/// Preferred UI language per user id (email/SMS use the **recipient**, not the sender).
abstract final class TGUserLocales {
  static final Map<String, String> _map = {};

  static void set(String userId, String locale) {
    final code = locale.split(RegExp('[_-]')).first.toLowerCase();
    if (userId.isEmpty || code.isEmpty) return;
    _map[userId] = code;
  }

  static String of(String userId, {String fallback = 'en'}) => _map[userId] ?? fallback;

  static void reset() => _map.clear();
}
