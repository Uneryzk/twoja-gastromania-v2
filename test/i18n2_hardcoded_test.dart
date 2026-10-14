import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/check_hardcoded_strings.dart';

void main() {
  test('f) hardcoded chrome ratchet — new hits fail, baseline removals allowed', () {
    final hits = scanHardcodedStrings(Directory('lib'));
    final baselineFile = File('tool/i18n_hardcoded_baseline.txt');
    expect(baselineFile.existsSync(), isTrue, reason: 'run: dart run tool/check_hardcoded_strings.dart --write-baseline');
    final baseline = loadBaseline(baselineFile);
    final ids = hits.map((h) => h.id).toSet();
    final added = ids.difference(baseline).toList()..sort();
    expect(added, isEmpty, reason: 'New hardcoded strings:\n${added.take(25).join('\n')}');
  });

  test('hand-built "N days" concatenation is forbidden in lib/', () {
    final banned = RegExp(
      r"""(\$\{?n\}? days|\$\{[^}]+\} days|' days'|" days"|' listings'|" listings")""",
    );
    final skip = RegExp(r'tg_l10n\.dart|duration_formatter\.dart|check_hardcoded_strings\.dart');
    final hits = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      if (skip.hasMatch(f.path)) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        if (banned.hasMatch(line)) hits.add('${f.path}:${i + 1}: ${line.trim()}');
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });
}
