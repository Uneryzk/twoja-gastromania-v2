import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// A Polish city with the data needed for location search and radius filters.
@immutable
class TGCity {
  const TGCity(this.name, this.voivodeship, this.lat, this.lng);

  final String name;
  final String voivodeship;
  final double lat;
  final double lng;
}

/// Tiny offline gazetteer + great-circle distance.
///
/// The marketplace has no geocoding backend yet, so listings only carry a city
/// name. Resolving that name to coordinates here is what lets the "radius"
/// filter and the "Nearest" sort actually work.
abstract final class TGGeo {
  static const List<TGCity> cities = [
    TGCity('Warszawa', 'Mazowieckie', 52.2297, 21.0122),
    TGCity('Kraków', 'Małopolskie', 50.0647, 19.9450),
    TGCity('Łódź', 'Łódzkie', 51.7592, 19.4560),
    TGCity('Wrocław', 'Dolnośląskie', 51.1079, 17.0385),
    TGCity('Poznań', 'Wielkopolskie', 52.4064, 16.9252),
    TGCity('Gdańsk', 'Pomorskie', 54.3520, 18.6466),
    TGCity('Szczecin', 'Zachodniopomorskie', 53.4285, 14.5528),
    TGCity('Bydgoszcz', 'Kujawsko-Pomorskie', 53.1235, 18.0084),
    TGCity('Lublin', 'Lubelskie', 51.2465, 22.5684),
    TGCity('Białystok', 'Podlaskie', 53.1325, 23.1688),
    TGCity('Katowice', 'Śląskie', 50.2649, 19.0238),
    TGCity('Gdynia', 'Pomorskie', 54.5189, 18.5305),
    TGCity('Częstochowa', 'Śląskie', 50.7965, 19.1200),
    TGCity('Radom', 'Mazowieckie', 51.4027, 21.1471),
    TGCity('Rzeszów', 'Podkarpackie', 50.0412, 21.9991),
    TGCity('Toruń', 'Kujawsko-Pomorskie', 53.0138, 18.5984),
    TGCity('Kielce', 'Świętokrzyskie', 50.8661, 20.6286),
    TGCity('Gliwice', 'Śląskie', 50.2945, 18.6714),
    TGCity('Zabrze', 'Śląskie', 50.3249, 18.7857),
    TGCity('Bielsko-Biała', 'Śląskie', 49.8224, 19.0584),
    TGCity('Olsztyn', 'Warmińsko-Mazurskie', 53.7784, 20.4801),
    TGCity('Rybnik', 'Śląskie', 50.0971, 18.5463),
    TGCity('Opole', 'Opolskie', 50.6751, 17.9213),
    TGCity('Zielona Góra', 'Lubuskie', 51.9356, 15.5062),
    TGCity('Tychy', 'Śląskie', 50.1218, 18.9664),
    TGCity('Sosnowiec', 'Śląskie', 50.2863, 19.1041),
    TGCity('Płock', 'Mazowieckie', 52.5463, 19.7065),
  ];

  static final Map<String, TGCity> _byKey = {
    for (final c in cities) normalize(c.name): c,
  };

  static const Map<String, String> _fold = {
    'ą': 'a', 'ć': 'c', 'ę': 'e', 'ł': 'l', 'ń': 'n', 'ó': 'o', 'ś': 's',
    'ź': 'z', 'ż': 'z', //
  };

  /// Lower-cases, trims and strips Polish diacritics so "Kraków", "krakow" and
  /// " KRAKÓW " all compare equal.
  static String normalize(String input) {
    final lower = input.trim().toLowerCase();
    final out = StringBuffer();
    for (final rune in lower.runes) {
      final ch = String.fromCharCode(rune);
      out.write(_fold[ch] ?? ch);
    }
    return out.toString();
  }

  static bool sameName(String a, String b) => normalize(a) == normalize(b);

  /// Resolves a (possibly sloppy) city name, or `null` when unknown.
  static TGCity? lookup(String? name) {
    if (name == null) return null;
    final key = normalize(name);
    if (key.isEmpty) return null;
    return _byKey[key];
  }

  /// Great-circle distance in kilometres (haversine).
  static double distanceKm(TGCity a, TGCity b) {
    const earthRadiusKm = 6371.0088;
    double rad(double deg) => deg * math.pi / 180.0;
    final dLat = rad(b.lat - a.lat);
    final dLng = rad(b.lng - a.lng);
    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(a.lat)) * math.cos(rad(b.lat)) * math.pow(math.sin(dLng / 2), 2);
    return 2 * earthRadiusKm * math.asin(math.min(1.0, math.sqrt(h)));
  }

  /// Distance between two city names, or `null` if either is unknown.
  static double? distanceBetween(String a, String b) {
    final ca = lookup(a);
    final cb = lookup(b);
    if (ca == null || cb == null) return null;
    return distanceKm(ca, cb);
  }
}
