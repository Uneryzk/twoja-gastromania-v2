/// Public listing prices must be a real number, never a single digit 0–9.
abstract final class TGListingPrice {
  static const int minPln = 10;

  static int? parse(String raw) {
    final n = int.tryParse(raw.replaceAll(RegExp(r'[^0-9]'), ''));
    return n;
  }

  static bool isValid(int? pln) => pln != null && pln >= minPln;
}
