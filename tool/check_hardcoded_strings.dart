#!/usr/bin/env dart
// Scans lib/ for chrome string literals. Run: dart run tool/check_hardcoded_strings.dart
// Exit 0 = no new violations vs tool/i18n_hardcoded_baseline.txt (ratchet).

import 'dart:io';

final _constructs = <String, RegExp>{
  'Text': RegExp(r"""Text\s*\(\s*(?:const\s+)?(['"])(.*?)\1"""),
  'hintText': RegExp(r"""hintText\s*:\s*(['"])(.*?)\1"""),
  'labelText': RegExp(r"""labelText\s*:\s*(['"])(.*?)\1"""),
  'helperText': RegExp(r"""helperText\s*:\s*(['"])(.*?)\1"""),
  'errorText': RegExp(r"""errorText\s*:\s*(['"])(.*?)\1"""),
  'tooltip': RegExp(r"""tooltip\s*:\s*(['"])(.*?)\1"""),
  'semanticLabel': RegExp(r"""semantic(?:sLabel|Label)\s*:\s*(['"])(.*?)\1"""),
  'SnackBar': RegExp(r"""SnackBar\s*\([^;]{0,200}?Text\s*\(\s*(['"])(.*?)\1""", dotAll: true),
  'label': RegExp(r"""(?:TGButton|[A-Za-z]+Button)\s*\([^;]{0,240}?label\s*:\s*(['"])(.*?)\1""", dotAll: true),
};

final _skipFile = RegExp(r'tg_l10n\.dart|internationalization\.dart|tg_user_text\.dart');
final _letters = RegExp(r'[A-Za-zĄąĆćĘęŁłŃńÓóŚśŹźŻżİıĞğŞşÄäÖöÜüß]');
final _keyLike = RegExp(r'^[a-z][a-z0-9_]*$');
final _asset = RegExp(r'^(assets/|package:|http)');

class Hit {
  Hit(this.file, this.line, this.construct, this.text);
  final String file;
  final int line;
  final String construct;
  final String text;
  String get id => '$file:$construct:${text.replaceAll('\n', r'\n')}';
}

List<Hit> scanHardcodedStrings(Directory lib) {
  final hits = <Hit>[];
  for (final f in lib.listSync(recursive: true).whereType<File>()) {
    if (!f.path.endsWith('.dart')) continue;
    final rel = f.path.replaceAll('\\', '/');
    final idx = rel.indexOf('/lib/');
    final file = idx >= 0 ? rel.substring(idx + 1) : rel;
    if (_skipFile.hasMatch(file)) continue;
    final src = f.readAsStringSync();
    final lines = src.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('//') || trimmed.startsWith('*') || trimmed.startsWith('import ')) continue;
      if (trimmed.contains('TGUserText(') || trimmed.contains('context.t(') || trimmed.contains('Key(')) continue;
      if (trimmed.contains('debugPrint') || trimmed.contains('track(') || trimmed.contains("path:")) continue;
      for (final e in _constructs.entries) {
        for (final m in e.value.allMatches(line)) {
          final text = m.group(m.groupCount)!;
          if (!_letters.hasMatch(text)) continue;
          if (_keyLike.hasMatch(text)) continue;
          if (_asset.hasMatch(text)) continue;
          if (text.contains(r'$') || text.contains('{')) continue;
          hits.add(Hit(file, i + 1, e.key, text));
        }
      }
    }
  }
  hits.sort((a, b) => a.id.compareTo(b.id));
  return hits;
}

Set<String> loadBaseline(File file) {
  if (!file.existsSync()) return {};
  return file
      .readAsLinesSync()
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !l.startsWith('#'))
      .toSet();
}

void writeBaseline(File file, List<Hit> hits) {
  final buf = StringBuffer('# I18N-2 hardcoded chrome baseline. Removing a line is allowed (ratchet).\n');
  for (final h in hits) {
    buf.writeln(h.id);
  }
  file.writeAsStringSync(buf.toString());
}

void main(List<String> args) {
  final root = Directory.current;
  final lib = Directory('${root.path}/lib');
  final baselineFile = File('${root.path}/tool/i18n_hardcoded_baseline.txt');
  final hits = scanHardcodedStrings(lib);
  if (args.contains('--write-baseline')) {
    writeBaseline(baselineFile, hits);
    stdout.writeln('Wrote ${hits.length} hits to ${baselineFile.path}');
    return;
  }
  final baseline = loadBaseline(baselineFile);
  final ids = hits.map((h) => h.id).toSet();
  final added = ids.difference(baseline).toList()..sort();
  if (added.isNotEmpty) {
    stderr.writeln('New hardcoded chrome strings (${added.length}). Move them to tg_l10n or restore the baseline:');
    for (final a in added.take(40)) {
      stderr.writeln('  $a');
    }
    if (added.length > 40) stderr.writeln('  … ${added.length - 40} more');
    exit(1);
  }
  stdout.writeln('Hardcoded scan OK (${ids.length} baseline, ${baseline.difference(ids).length} cleared).');
}
