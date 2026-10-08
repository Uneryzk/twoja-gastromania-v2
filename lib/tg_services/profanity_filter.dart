/// Multilingual profanity / hate-speech filter (PL, EN, TR, DE).
class TGProfanityFilter {
  const TGProfanityFilter();

  static const _banned = <String>{
    // English
    'fuck', 'fucking', 'shit', 'bitch', 'asshole', 'cunt', 'whore', 'slut',
    'nigger', 'nigga', 'faggot', 'retard', 'kike', 'spic', 'chink',
    'nazi', 'hitler',
    // Polish
    'kurwa', 'chuj', 'cipa', 'jebac', 'jebać', 'pierdol', 'pierdolic', 'pierdolić',
    'skurwysyn', 'suka', 'dziwka', 'cwel', 'pedal', 'pedał', 'ciota',
    'czarnuch', 'zydow', 'żydów', 'hitlerowiec', 'pojeb',
    // Turkish
    'amk', 'aq', 'orospu', 'pic', 'piç', 'siktir', 'sikerim', 'gotunu', 'götünü',
    'gerizekali', 'gerizekalı', 'ibne', 'yavsak', 'yavşak', 'kahpe',
    // German
    'scheisse', 'scheiße', 'fotze', 'hurensohn', 'arschloch', 'schlampe',
    'kanake', 'neger', 'wichser',
  };

  static const _phrases = <String>[
    'kill yourself',
    'gas the',
    'heil hitler',
    'white power',
    'death to',
    'siktir git',
    'orospu cocugu',
    'orospu çocuğu',
    'son of a bitch',
  ];

  bool isBlocked(String raw) => hit(raw) != null;

  String? hit(String raw) {
    final n = _normalize(raw);
    if (n.isEmpty) return null;
    for (final phrase in _phrases) {
      if (n.contains(_normalize(phrase))) return phrase;
    }
    final tokens = n.split(RegExp(r'[^a-z0-9]+')).where((t) => t.length >= 2);
    for (final token in tokens) {
      if (_banned.contains(token)) return token;
    }
    return null;
  }

  static String _normalize(String s) {
    final b = StringBuffer();
    for (final r in s.toLowerCase().replaceAll('ß', 'ss').runes) {
      b.writeCharCode(_fold(r));
    }
    return b.toString();
  }

  static int _fold(int r) => switch (r) {
        0x0105 || 0x00E1 || 0x00E0 => 0x61, // ą á à -> a
        0x0107 || 0x00E7 => 0x63, // ć ç
        0x0119 => 0x65, // ę
        0x0142 => 0x6C, // ł
        0x0144 => 0x6E, // ń
        0x00F3 || 0x00F6 => 0x6F, // ó ö
        0x015B || 0x015F || 0x015E => 0x73, // ś ş
        0x017A || 0x017C || 0x017E => 0x7A, // ź ż ž
        0x00E4 => 0x61, // ä
        0x00FC => 0x75, // ü
        0x00DF => 0x73, // ß ~ s (we also check 'ss' phrases separately)
        0x011F => 0x67, // ğ
        0x0131 || 0x0130 => 0x69, // ı İ
        _ => r,
      };
}
