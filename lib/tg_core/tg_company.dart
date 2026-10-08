/// Company details shown in the footer.
///
/// NOTE: these are the placeholder values that were already hard-coded in the
/// footer – replace them with the real company data in this one place.
abstract final class TGCompany {
  static const String name = 'Twoja Gastromania';
  static const String tagline = 'Industrial kitchen equipment listings for professionals.';

  static const String addressLine = 'ul. Example 12';
  static const String city = 'Warszawa';
  static String get fullAddress => '$addressLine, $city';

  static const String phone = '+48 000 000 000';
  static const String email = 'hello@twojagastromania.com';
  static const String hours = 'Mon–Fri 09:00–18:00';

  /// Map pin (centre of Warszawa until the real address is geocoded).
  static const double lat = 52.2297;
  static const double lng = 21.0122;

  /// Deep link that opens the location in the platform's maps app / Google Maps.
  static Uri get mapsUri => Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': '$lat,$lng',
      });

  static Uri get emailUri => Uri(scheme: 'mailto', path: email);

  /// Optional social profiles. Icons are only rendered for entries that have a
  /// URL, so the footer never shows dead social buttons.
  static const Map<String, String?> social = {
    'Facebook': null,
    'Instagram': null,
    'LinkedIn': null,
    'YouTube': null,
  };
}
