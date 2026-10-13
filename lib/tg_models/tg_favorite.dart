import 'package:flutter/foundation.dart';

enum FavoriteKind { equipment, restaurant }

/// A saved listing. The snapshot fields keep the card readable after the
/// listing itself is gone (sold, expired, removed).
@immutable
class TGFavorite {
  const TGFavorite({
    required this.userId,
    required this.kind,
    required this.listingId,
    required this.savedAt,
    required this.title,
    required this.imageUrl,
    required this.path,
    this.listingNo,
    this.city = '',
    this.priceAtSave,
    this.isMock = false,
  });

  final String userId;
  final FavoriteKind kind;
  final String listingId;
  final DateTime savedAt;
  final String title;
  final String imageUrl;
  final String path;
  final String? listingNo;
  final String city;
  final int? priceAtSave;
  final bool isMock;

  String get key => '$userId|${kind.name}|$listingId';
}

/// One recorded price edit: `oldPln → newPln` on [at].
@immutable
class PriceHistory {
  const PriceHistory({
    required this.listingId,
    required this.at,
    required this.oldPln,
    required this.newPln,
    this.isMock = false,
  });

  final String listingId;
  final DateTime at;
  final int oldPln;
  final int newPln;
  final bool isMock;

  bool get dropped => newPln < oldPln;
}
