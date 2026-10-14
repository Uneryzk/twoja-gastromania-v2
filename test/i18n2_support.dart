import 'dart:io';

import 'package:twoja_gastromania/flutter_flow/tg_l10n.dart';

const kI18nPrimary = ['tr', 'en', 'pl'];

final englishStopWords = {
  'the', 'and', 'for', 'with', 'this', 'that', 'from', 'your', 'have', 'been',
  'will', 'are', 'were', 'you', 'our', 'their', 'they', 'them',
  'has', 'had', 'but', 'its', 'into', 'about', 'than', 'then', 'these', 'those',
  'over', 'after', 'before', 'more', 'most', 'some', 'any', 'can',
  'should', 'would', 'could', 'being', 'also', 'just', 'only', 'onto',
};

Set<String> loadAllowlist() {
  final file = File('tool/i18n_allowlist.txt');
  if (!file.existsSync()) return {};
  return file
      .readAsLinesSync()
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !l.startsWith('#'))
      .map((l) => l.toLowerCase())
      .toSet();
}

final latinWord = RegExp(r"[A-Za-zÀ-žİıĞğŞşÄäÖöÜüßÁáÉéÍíÓóÚúÇçŃńŚśŹźŻżŁł]+");

bool allowlistedValue(String value, Set<String> allow) {
  final stripped = value
      .replaceAll(RegExp(r'\{[^{}]+\}'), ' ')
      .replaceAll(RegExp(r'[#·•—–/_,.;:()\[\]%+]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .toLowerCase();
  if (stripped.isEmpty) return true;
  if (allow.contains(stripped)) return true;
  final tokens = stripped.split(' ').where((t) => t.isNotEmpty).toList();
  if (tokens.isEmpty) return true;
  bool ok(String t) =>
      t.length <= 3 || allow.contains(t) || RegExp(r'^\d+(-\d+)?$').hasMatch(t);
  return tokens.every(ok);
}

List<String> visibleWords(String value) {
  final stripped = value.replaceAll(RegExp(r'\{[^{}]+\}'), ' ');
  return latinWord.allMatches(stripped).map((m) => m.group(0)!.toLowerCase()).toList();
}

Set<String> simplePlaceholders(String s) {
  final names = <String>{};
  final icu = RegExp(r'\{([a-zA-Z_][a-zA-Z0-9_]*)\s*,');
  for (final m in icu.allMatches(s)) {
    names.add(m.group(1)!);
  }
  final simple = RegExp(r'\{([a-zA-Z_][a-zA-Z0-9_]*)\}');
  for (final m in simple.allMatches(s)) {
    names.add(m.group(1)!);
  }
  return names;
}

List<String> icuPluralBodies(String s) {
  final out = <String>[];
  var i = 0;
  while (i < s.length) {
    final start = s.indexOf(', plural,', i);
    if (start < 0) break;
    var open = s.lastIndexOf('{', start);
    if (open < 0) break;
    var depth = 0;
    var end = -1;
    for (var j = open; j < s.length; j++) {
      if (s[j] == '{') depth++;
      if (s[j] == '}') {
        depth--;
        if (depth == 0) {
          end = j;
          break;
        }
      }
    }
    if (end < 0) break;
    out.add(s.substring(open, end + 1));
    i = end + 1;
  }
  return out;
}

Set<String> icuCases(String block) {
  final cases = <String>{};
  final idx = block.indexOf(', plural,');
  if (idx < 0) return cases;
  var i = idx + ', plural,'.length;
  while (i < block.length) {
    while (i < block.length && block[i].trim().isEmpty) {
      i++;
    }
    if (i >= block.length || block[i] == '}') break;
    final open = block.indexOf('{', i);
    if (open < 0) break;
    final selector = block.substring(i, open).trim();
    if (selector.isNotEmpty) cases.add(selector);
    var depth = 0;
    var j = open;
    for (; j < block.length; j++) {
      if (block[j] == '{') depth++;
      if (block[j] == '}') {
        depth--;
        if (depth == 0) break;
      }
    }
    i = j + 1;
  }
  return cases;
}

Map<String, String> row(String key) => kUiTranslations[key] ?? const {};
