import 'dart:math';

import 'package:twoja_gastromania/tg_models/tg_product.dart';

/// 8-digit, non-sequential listing numbers. Assigned once when a draft is
/// published or sent to payment; never reused, never changed on edit/renew.
abstract final class TGListingNo {
  static final Set<String> _used = {};
  static final Random _rng = Random();
  static final RegExp _eightDigits = RegExp(r'^\d{8}$');
  static final RegExp _pathNo = RegExp(r'^(\d{8})(?:-|$)');

  static bool isListingNo(String raw) => _eightDigits.hasMatch(raw.trim());

  static void reserve(String? no) {
    final n = no?.trim();
    if (n != null && _eightDigits.hasMatch(n)) _used.add(n);
  }

  static void reserveAll(Iterable<String?> numbers) {
    for (final n in numbers) {
      reserve(n);
    }
  }

  static String allocate() {
    String n;
    do {
      n = (10000000 + _rng.nextInt(90000000)).toString();
    } while (_used.contains(n));
    _used.add(n);
    return n;
  }

  static String? parseFromPath(String segment) => _pathNo.firstMatch(segment)?.group(1);

  static String slug(String title) {
    final ascii = title
        .toLowerCase()
        .replaceAll(RegExp(r'[àáâãäå]'), 'a')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[òóôõö]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[ñ]'), 'n')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final clipped = ascii.length > 60 ? ascii.substring(0, 60).replaceAll(RegExp(r'-$'), '') : ascii;
    return clipped.isEmpty ? 'listing' : clipped;
  }

  static String path(TGProduct product) {
    final no = product.listingNo;
    if (no == null || no.isEmpty) return '/product-detail/${product.id}';
    return '/product-detail/$no-${slug(product.title)}';
  }

  static TGProduct? findPublic(Iterable<TGProduct> all, String number) {
    final n = number.trim();
    for (final p in all) {
      if (p.listingNo == n) return p.isPubliclyVisible ? p : null;
    }
    return null;
  }
}

extension TGProductDetailPath on TGProduct {
  String get detailPath => TGListingNo.path(this);
}
