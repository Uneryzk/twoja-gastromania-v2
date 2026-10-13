import 'dart:typed_data';

/// Removes location / camera metadata from uploaded photos before they are
/// attached to a message. JPEG: drops APP1 (EXIF, XMP) and APP13 (IPTC)
/// segments. PNG: drops `eXIf` chunks. Other data is copied byte for byte.
abstract final class TGExif {
  static bool isJpeg(Uint8List b) => b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF;

  static bool isPng(Uint8List b) =>
      b.length >= 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47;

  static String? sniffMime(Uint8List b) {
    if (isJpeg(b)) return 'image/jpeg';
    if (isPng(b)) return 'image/png';
    if (b.length >= 12 && String.fromCharCodes(b.sublist(0, 4)) == 'RIFF' && String.fromCharCodes(b.sublist(8, 12)) == 'WEBP') {
      return 'image/webp';
    }
    return null;
  }

  /// True when the JPEG / PNG still carries an EXIF block.
  static bool hasExif(Uint8List b) {
    if (isJpeg(b)) return _jpegSegments(b).any((s) => s.marker == 0xE1);
    if (isPng(b)) return _pngChunks(b).any((c) => c.type == 'eXIf');
    return false;
  }

  static Uint8List strip(Uint8List b) {
    if (isJpeg(b)) return _stripJpeg(b);
    if (isPng(b)) return _stripPng(b);
    return b;
  }

  static Uint8List _stripJpeg(Uint8List b) {
    final out = BytesBuilder(copy: false)..add([0xFF, 0xD8]);
    for (final s in _jpegSegments(b)) {
      if (s.marker == 0xE1 || s.marker == 0xED) continue;
      out.add(Uint8List.sublistView(b, s.start, s.end));
    }
    return out.toBytes();
  }

  static Iterable<({int marker, int start, int end})> _jpegSegments(Uint8List b) sync* {
    var i = 2;
    while (i + 4 <= b.length) {
      if (b[i] != 0xFF) {
        yield (marker: -1, start: i, end: b.length);
        return;
      }
      final marker = b[i + 1];
      if (marker == 0xDA) {
        // Start of scan: the compressed image runs to the end of the file.
        yield (marker: marker, start: i, end: b.length);
        return;
      }
      if (marker == 0xD9) {
        yield (marker: marker, start: i, end: i + 2);
        return;
      }
      final len = (b[i + 2] << 8) | b[i + 3];
      final end = i + 2 + len;
      if (len < 2 || end > b.length) {
        yield (marker: -1, start: i, end: b.length);
        return;
      }
      yield (marker: marker, start: i, end: end);
      i = end;
    }
  }

  static Uint8List _stripPng(Uint8List b) {
    final out = BytesBuilder(copy: false)..add(Uint8List.sublistView(b, 0, 8));
    for (final c in _pngChunks(b)) {
      if (c.type == 'eXIf') continue;
      out.add(Uint8List.sublistView(b, c.start, c.end));
    }
    return out.toBytes();
  }

  static Iterable<({String type, int start, int end})> _pngChunks(Uint8List b) sync* {
    var i = 8;
    while (i + 12 <= b.length) {
      final len = (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];
      final end = i + 12 + len;
      if (len < 0 || end > b.length) return;
      yield (type: String.fromCharCodes(b.sublist(i + 4, i + 8)), start: i, end: end);
      i = end;
    }
  }
}
