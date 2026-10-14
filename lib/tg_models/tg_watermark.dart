import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';

// SECURITY: the client-side overlay is NOT real protection — the raw file URL
// stays reachable. In production the watermark must be burned into the
// derivatives on the server and the original must never be served publicly.

enum TGWatermarkPosition { center, topLeft, topRight, bottomLeft, bottomRight }

extension TGWatermarkPositionX on TGWatermarkPosition {
  String get wire => switch (this) {
        TGWatermarkPosition.center => 'center',
        TGWatermarkPosition.topLeft => 'top_left',
        TGWatermarkPosition.topRight => 'top_right',
        TGWatermarkPosition.bottomLeft => 'bottom_left',
        TGWatermarkPosition.bottomRight => 'bottom_right',
      };

  Alignment get alignment => switch (this) {
        TGWatermarkPosition.center => Alignment.center,
        TGWatermarkPosition.topLeft => const Alignment(-0.92, -0.92),
        TGWatermarkPosition.topRight => const Alignment(0.92, -0.92),
        TGWatermarkPosition.bottomLeft => const Alignment(-0.92, 0.92),
        TGWatermarkPosition.bottomRight => const Alignment(0.92, 0.92),
      };

  static TGWatermarkPosition fromWire(String? v) =>
      TGWatermarkPosition.values.firstWhere((p) => p.wire == v, orElse: () => TGWatermarkPosition.center);
}

/// Admin-editable watermark rules (/admin/watermark).
@immutable
class WatermarkConfig {
  const WatermarkConfig({
    this.enabled = true,
    this.version = 1,
    this.markAsset = kDefaultMarkAsset,
    this.opacity = 0.12,
    this.widthRatio = 0.22,
    this.position = TGWatermarkPosition.center,
    this.minImageWidthPx = 200,
  });

  static const kDefaultMarkAsset = 'assets/images/tg_watermark_mark.png';

  final bool enabled;
  final int version;

  /// Transparent PNG/SVG mark.
  final String markAsset;
  final double opacity;

  /// Mark width as a share of the rendered image width.
  final double widthRatio;
  final TGWatermarkPosition position;

  /// Images rendered narrower than this (logical px) are left unmarked.
  final int minImageWidthPx;

  WatermarkConfig copyWith({
    bool? enabled,
    int? version,
    String? markAsset,
    double? opacity,
    double? widthRatio,
    TGWatermarkPosition? position,
    int? minImageWidthPx,
  }) =>
      WatermarkConfig(
        enabled: enabled ?? this.enabled,
        version: version ?? this.version,
        markAsset: markAsset ?? this.markAsset,
        opacity: opacity ?? this.opacity,
        widthRatio: widthRatio ?? this.widthRatio,
        position: position ?? this.position,
        minImageWidthPx: minImageWidthPx ?? this.minImageWidthPx,
      );

  /// Changes that alter the rendered pixels (and so need a reprocess).
  bool visuallyDiffers(WatermarkConfig o) =>
      enabled != o.enabled ||
      markAsset != o.markAsset ||
      opacity != o.opacity ||
      widthRatio != o.widthRatio ||
      position != o.position ||
      minImageWidthPx != o.minImageWidthPx;

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'version': version,
        'markAsset': markAsset,
        'opacity': opacity,
        'widthRatio': widthRatio,
        'position': position.wire,
        'minImageWidthPx': minImageWidthPx,
      };

  factory WatermarkConfig.fromJson(Map<String, dynamic> j) => WatermarkConfig(
        enabled: j['enabled'] as bool? ?? true,
        version: (j['version'] as num?)?.toInt() ?? 1,
        markAsset: j['markAsset'] as String? ?? kDefaultMarkAsset,
        opacity: (j['opacity'] as num?)?.toDouble() ?? 0.12,
        widthRatio: (j['widthRatio'] as num?)?.toDouble() ?? 0.22,
        position: TGWatermarkPositionX.fromWire(j['position'] as String?),
        minImageWidthPx: (j['minImageWidthPx'] as num?)?.toInt() ?? 200,
      );

  @override
  bool operator ==(Object other) => other is WatermarkConfig && other.version == version && !visuallyDiffers(other);

  @override
  int get hashCode => Object.hash(enabled, version, markAsset, opacity, widthRatio, position, minImageWidthPx);
}

/// Where an image is rendered. Only listing photos are watermarked.
enum TGImageSurface {
  listingGrid,
  listingCard,
  listingDetail,
  lightbox,
  favorites,
  sharePreview,
  uploadPreview,
  // Out of scope — never watermarked.
  specialOrderFile,
  legalDocument,
  messageAttachment,
  avatar,
  storeLogo,
  storeCover,
  banner,
  hero,
  adSlot,
  sponsorSlot,
}

const Set<TGImageSurface> kWatermarkExcludedSurfaces = {
  TGImageSurface.specialOrderFile,
  TGImageSurface.legalDocument,
  TGImageSurface.messageAttachment,
  TGImageSurface.avatar,
  TGImageSurface.storeLogo,
  TGImageSurface.storeCover,
  TGImageSurface.banner,
  TGImageSurface.hero,
  TGImageSurface.adSlot,
  TGImageSurface.sponsorSlot,
};

bool watermarkAppliesTo(TGImageSurface surface) => !kWatermarkExcludedSurfaces.contains(surface);

/// Server-side derivative sizes (longest edge, px).
enum TGImageVariant { thumb, card, detail, lightbox }

extension TGImageVariantX on TGImageVariant {
  int get widthPx => switch (this) {
        TGImageVariant.thumb => 320,
        TGImageVariant.card => 640,
        TGImageVariant.detail => 1280,
        TGImageVariant.lightbox => 2000,
      };

  /// Smallest variant covering [physicalWidth].
  static TGImageVariant forWidth(double physicalWidth) =>
      TGImageVariant.values.firstWhere((v) => v.widthPx >= physicalWidth, orElse: () => TGImageVariant.lightbox);
}

/// One listing photo. [originalRef] is private: it never appears in [toJson]
/// and is only readable by staff through [originalRefFor].
@immutable
class ListingImage {
  const ListingImage._({
    required this.id,
    required this.listingKey,
    required this.index,
    required String originalRef,
    required this.variants,
    required this.uploadedById,
    required this.uploadedByName,
    required this.uploadedAt,
    this.phash,
    this.watermarked = false,
    this.watermarkVersion = 0,
  }) : _originalRef = originalRef;

  factory ListingImage.upload({
    required String id,
    required String listingKey,
    required int index,
    required String originalRef,
    required Map<TGImageVariant, String> variants,
    required String uploadedById,
    required String uploadedByName,
    required DateTime uploadedAt,
    String? phash,
  }) =>
      ListingImage._(
        id: id,
        listingKey: listingKey,
        index: index,
        originalRef: originalRef,
        variants: Map.unmodifiable(variants),
        uploadedById: uploadedById,
        uploadedByName: uploadedByName,
        uploadedAt: uploadedAt,
        phash: phash,
      );

  final String id;
  final String listingKey;
  final int index;
  final String _originalRef;

  /// 64-bit perceptual hash of the ORIGINAL (hex), never of a watermarked variant.
  final String? phash;
  final Map<TGImageVariant, String> variants;
  final bool watermarked;
  final int watermarkVersion;
  final String uploadedById;
  final String uploadedByName;
  final DateTime uploadedAt;

  String? originalRefFor(TGUserRole role) => role.isStaff ? _originalRef : null;

  String variant(TGImageVariant v) => variants[v] ?? variants.values.first;

  /// Single public access point for listing photo URLs. Staff `originalRef`
  /// values (`originals/…`, `originalRef=`) never leave this method.
  static String publicVariant(String url, [TGImageVariant variant = TGImageVariant.card]) {
    final u = url.trim();
    if (u.isEmpty) return '';
    final lower = u.toLowerCase();
    if (lower.startsWith('originals/') ||
        lower.contains('/originals/') ||
        lower.contains('originalref=') ||
        lower.contains('original_ref')) {
      return '';
    }
    return switch (variant) { _ => u };
  }

  ListingImage copyWith({String? phash, bool? watermarked, int? watermarkVersion}) => ListingImage._(
        id: id,
        listingKey: listingKey,
        index: index,
        originalRef: _originalRef,
        variants: variants,
        uploadedById: uploadedById,
        uploadedByName: uploadedByName,
        uploadedAt: uploadedAt,
        phash: phash ?? this.phash,
        watermarked: watermarked ?? this.watermarked,
        watermarkVersion: watermarkVersion ?? this.watermarkVersion,
      );

  /// Public API shape — no original reference, no hash.
  Map<String, dynamic> toJson() => {
        'id': id,
        'listingKey': listingKey,
        'index': index,
        'variants': {for (final e in variants.entries) e.key.name: e.value},
        'watermarked': watermarked,
        'watermarkVersion': watermarkVersion,
      };

  /// Admin / moderator shape. Throws for any other role.
  Map<String, dynamic> toStaffJson(TGUserRole role) {
    if (!role.isStaff) throw StateError('originalRef is restricted to admin/moderator');
    return {
      ...toJson(),
      'originalRef': _originalRef,
      'phash': phash,
      'uploadedById': uploadedById,
      'uploadedAt': uploadedAt.toIso8601String(),
    };
  }

  /// Parses the public shape; the original reference is never restored from it.
  factory ListingImage.fromPublicJson(Map<String, dynamic> j) => ListingImage._(
        id: j['id'] as String,
        listingKey: j['listingKey'] as String? ?? '',
        index: (j['index'] as num?)?.toInt() ?? 0,
        originalRef: '',
        variants: {
          for (final e in ((j['variants'] as Map?) ?? const {}).entries)
            TGImageVariant.values.firstWhere((v) => v.name == e.key, orElse: () => TGImageVariant.card): e.value.toString(),
        },
        uploadedById: '',
        uploadedByName: '',
        uploadedAt: DateTime.fromMillisecondsSinceEpoch(0),
        watermarked: j['watermarked'] as bool? ?? false,
        watermarkVersion: (j['watermarkVersion'] as num?)?.toInt() ?? 0,
      );

  @override
  String toString() => 'ListingImage($id, $listingKey#$index, v$watermarkVersion)';
}

/// DCT perceptual hash (64 bits, hex).
class TGPhash {
  TGPhash._();

  static const int size = 32;
  static const int matchThresholdBits = 10;

  static final List<List<double>> _cos = [
    for (var u = 0; u < size; u++) [for (var x = 0; x < size; x++) math.cos((2 * x + 1) * u * math.pi / (2 * size))],
  ];

  /// [gray] is 32×32 row-major luminance in 0..1.
  static String fromGray(List<double> gray) {
    assert(gray.length == size * size);
    final coeffs = <double>[];
    for (var v = 0; v < 8; v++) {
      for (var u = 0; u < 8; u++) {
        var s = 0.0;
        for (var y = 0; y < size; y++) {
          var row = 0.0;
          for (var x = 0; x < size; x++) {
            row += gray[y * size + x] * _cos[u][x];
          }
          s += _cos[v][y] * row;
        }
        coeffs.add(s);
      }
    }
    final ac = coeffs.sublist(1)..sort();
    final median = (ac[31] + ac[32]) / 2;
    var hex = StringBuffer();
    for (var nibble = 0; nibble < 16; nibble++) {
      var n = 0;
      for (var b = 0; b < 4; b++) {
        n = (n << 1) | (coeffs[nibble * 4 + b] > median ? 1 : 0);
      }
      hex.write(n.toRadixString(16));
    }
    return hex.toString();
  }

  /// Decodes [encoded] at 32×32 and hashes it (upload-time, on the original).
  static Future<String> fromEncoded(Uint8List encoded) async {
    final codec = await ui.instantiateImageCodec(encoded, targetWidth: size, targetHeight: size);
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
    frame.image.dispose();
    final px = data!.buffer.asUint8List();
    return fromGray([
      for (var i = 0; i < size * size; i++) (0.299 * px[i * 4] + 0.587 * px[i * 4 + 1] + 0.114 * px[i * 4 + 2]) / 255,
    ]);
  }

  static int distance(String a, String b) {
    var d = 0;
    for (var i = 0; i < 16; i++) {
      var x = int.parse(a[i], radix: 16) ^ int.parse(b[i], radix: 16);
      while (x != 0) {
        d += x & 1;
        x >>= 1;
      }
    }
    return d;
  }

  static int similarityPercent(int distance) => ((64 - distance) * 100 / 64).round();
}

/// Result of comparing two listings' originals.
@immutable
class TGOriginalMatch {
  const TGOriginalMatch({required this.distance, required this.earlier, required this.later});
  final int distance;

  /// Upload that came first — reported as "the original".
  final ListingImage earlier;
  final ListingImage later;

  bool get isMatch => distance <= TGPhash.matchThresholdBits;
  int get similarityPercent => TGPhash.similarityPercent(distance);
}
