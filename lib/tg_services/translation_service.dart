/// DeepL / Google Translate stub. Marketplace copy always targets English
/// as the common language — swap [translate] for a live HTTP client later.
class TranslationService {
  TranslationService._();
  static final TranslationService instance = TranslationService._();

  static const linguaFranca = 'en';

  static const _plHints = [
    'ą', 'ć', 'ę', 'ł', 'ń', 'ó', 'ś', 'ź', 'ż',
    'serwisowany', 'gotowy', 'zestawie', 'ogłoszen', 'wysyłka', 'odbiór',
    'piec', 'zmywarka', 'szafa', 'gastronom', 'nierdzewn', 'kartonie',
    'krajalnica', 'chleba', 'wygasła', 'wygasla', 'witryna', 'chłodnicz',
    'cukiernicz', 'przegląd', 'kawiarni', 'nowa', 'sprawna', 'używany',
    'ogłoszenie', 'sprzedam', 'wynajem', 'prowadnice',
    'dostępne', 'sprzedający', 'zdjęcia', 'tabliczka', 'spiłowan',
  ];

  static const _trHints = [
    'ğ', 'ş', 'ı', 'ç', 'satılık', 'kiralık', 'çalışır', 'açıklama',
    'fırın', 'buzdolabı', 'tezgah', 'temiz', 'kullanılmış', 'garanti',
  ];

  String detectLanguage(String text) {
    final t = text.toLowerCase();
    if (_plHints.any(t.contains) || RegExp(r'[ąćęłńóśźż]').hasMatch(t)) return 'pl';
    if (_trHints.any(t.contains) || RegExp(r'[ğüşıöç]').hasMatch(t)) return 'tr';
    if (RegExp(r'[äöüß]').hasMatch(t)) return 'de';
    return 'en';
  }

  bool needsEnglish(String text) {
    if (text.trim().isEmpty) return false;
    return detectLanguage(text) != linguaFranca;
  }

  bool needsTranslation(String text, String targetLang) {
    if (text.trim().isEmpty) return false;
    return detectLanguage(text) != targetLang;
  }

  Future<String> translate(String text, {String targetLang = linguaFranca, String? sourceLang}) async {
    await Future<void>.delayed(const Duration(milliseconds: 40));
    if (text.trim().isEmpty) return text;
    final src = sourceLang ?? detectLanguage(text);
    if (src == targetLang) return text;
    if (targetLang == 'en') return _toEnglish(text, src);
    if (targetLang == 'tr') {
      if (src == 'en') return _apply(_enTr, text);
      return _apply(_enTr, _toEnglish(text, src));
    }
    return text;
  }

  String _toEnglish(String text, String src) {
    final dict = src == 'tr' ? _trEn : src == 'de' ? _deEn : _plEn;
    return _apply(dict, text);
  }

  static String _apply(Map<String, String> dict, String text) {
    var out = text;
    for (final e in dict.entries) {
      out = out.replaceAll(e.key, e.value);
      if (e.key != e.key.toLowerCase()) {
        out = out.replaceAll(e.key.toLowerCase(), e.value.toLowerCase());
      }
    }
    return out;
  }

  static const _plEn = <String, String>{
    'Piec konwekcyjno-parowy': 'Combi steamer',
    'Krajalnica chleba': 'Bread slicer',
    'Krajalnica': 'Bread slicer',
    'wygasła': 'expired',
    'Wygasła': 'Expired',
    'chleba': 'bread',
    'Serwisowany, gotowy do pracy': 'Serviced, ready for use',
    'Serwisowany': 'Serviced',
    'gotowy do pracy': 'ready for use',
    'W zestawie': 'Includes',
    'prowadnice': 'racks',
    'wąż odpływowy': 'drain hose',
    'Nowa, w kartonie': 'New, boxed',
    'Nowa': 'New',
    'w kartonie': 'boxed',
    'Programy eco': 'Eco programs',
    'szybki cykl': 'fast cycle',
    'automatyczne dozowanie': 'automatic dosing',
    'Nowy stół roboczy': 'New work table',
    'idealny do zaplecza kuchennego': 'ideal for a kitchen back-of-house',
    'Faktura VAT': 'VAT invoice',
    'Sprawna': 'In working order',
    'Odbiór osobisty lub wysyłka': 'Pickup or shipping',
    'Po przeglądzie': 'After a service check',
    'Idealny do startu kawiarni': 'Ideal to start a café',
    'lub food trucka': 'or a food truck',
    'Witryna chłodnicza cukiernicza': 'Pastry refrigerated display',
    'Sprzedający poprosił o przelew na zagraniczne konto poza platformą. To wygląda na oszustwo.': 'The seller asked for a transfer to a foreign account off-platform. This looks like a scam.',
    'Sprzedający poprosił o przelew BLIK na prywatny numer.': 'The seller asked for a BLIK transfer to a private number.',
    'Sprzedający poprosił o przelew BLIK przed odbiorem.': 'The seller asked for a BLIK transfer before pickup.',
    'Tabliczka z numerem seryjnym wygląda na spiłowaną na 3. zdjęciu.': 'The serial plate looks filed off in the 3rd photo.',
    'Te zdjęcia skopiowano z naszego katalogu.': 'These photos were copied from our catalogue.',
    'To ogłoszenie wygląda na sprzedane.': 'This listing looks sold.',
    'Czy to ogłoszenie jest jeszcze dostępne?': 'Is this listing still available?',
    'Tak — odbiór osobisty w Katowicach.': 'Yes — pickup in Katowice.',
    'odbiór osobisty': 'pickup',
    'Katowicach': 'Katowice',
  };

  static const _enTr = <String, String>{
    'Combi steamer': 'Konveksiyonlu fırın',
    'Bread slicer': 'Ekmek dilimleyici',
    'expired': 'süresi doldu',
    'Expired': 'Süresi doldu',
    'Serviced, ready for use': 'Servis gördü, kullanıma hazır',
    'Serviced': 'Servis gördü',
    'ready for use': 'kullanıma hazır',
    'Includes': 'Dahil',
    'New, boxed': 'Yeni, kutulu',
    'VAT invoice': 'KDV faturası',
    'In working order': 'Çalışır durumda',
    'Pickup or shipping': 'Elden teslim veya kargo',
    'The seller asked for a transfer to a foreign account off-platform. This looks like a scam.': 'Satıcı platform dışında yabancı hesaba transfer istedi. Dolandırıcılık gibi duruyor.',
    'The seller asked for a BLIK transfer to a private number.': 'Satıcı özel bir numaraya BLIK transferi istedi.',
    'The seller asked for a BLIK transfer before pickup.': 'Satıcı teslimattan önce BLIK transferi istedi.',
    'The serial plate looks filed off in the 3rd photo.': '3. fotoğrafta seri plakası törpülenmiş görünüyor.',
    'These photos were copied from our catalogue.': 'Bu fotoğraflar kataloğumuzdan kopyalanmış.',
    'This listing looks sold.': 'Bu ilan satılmış görünüyor.',
    'Yes — pickup in Katowice.': 'Evet — Katowice’de teslim alınabilir.',
    'Is this listing still available?': 'Bu ilan hâlâ satılık mı?',
    'Is this still available?': 'Hâlâ satılık mı?',
    'For sale': 'Satılık',
    'For rent': 'Kiralık',
  };

  static const _trEn = <String, String>{
    'Satılık': 'For sale',
    'Kiralık': 'For rent',
    'Çalışır durumda': 'In working order',
    'Temiz': 'Clean',
    'Kullanılmış': 'Used',
    'Açıklama': 'Description',
    'Fırın': 'Oven',
    'Buzdolabı': 'Refrigerator',
  };

  static const _deEn = <String, String>{
    'Gebraucht': 'Used',
    'Neu': 'New',
    'Versand möglich': 'Shipping available',
  };
}

String languageDisplayName(String code) => switch (code) {
      'pl' => 'polski',
      'en' => 'English',
      'tr' => 'Türkçe',
      'de' => 'Deutsch',
      'cs' => 'čeština',
      'sk' => 'slovenčina',
      'uk' => 'українська',
      'be' => 'беларуская',
      'lt' => 'lietuvių',
      'ru' => 'русский',
      _ => code,
    };
