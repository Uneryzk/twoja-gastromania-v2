import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/flutter_flow/tg_l10n.dart';

import 'i18n2_support.dart';

void main() {
  final allow = loadAllowlist();

  test('a) TR/EN/PL key sets match and values are non-empty', () {
    final missing = <String>[];
    for (final key in kUiTranslations.keys) {
      final m = kUiTranslations[key]!;
      for (final lang in kI18nPrimary) {
        final v = m[lang];
        if (v == null || v.trim().isEmpty) missing.add('$key@$lang');
      }
    }
    expect(missing, isEmpty, reason: missing.take(20).join('\n'));
  });

  test('b) placeholder sets match across TR/EN/PL', () {
    final bad = <String>[];
    for (final key in kUiTranslations.keys) {
      final m = kUiTranslations[key]!;
      final en = simplePlaceholders(m['en'] ?? '');
      for (final lang in ['tr', 'pl']) {
        final got = simplePlaceholders(m[lang] ?? '');
        if (got.length != en.length || !got.containsAll(en)) {
          bad.add('$key $lang $got != $en');
        }
      }
    }
    expect(bad, isEmpty, reason: bad.take(20).join('\n'));
  });

  test('c) plural keys have PL one/few/many/other and TR/EN one/other', () {
    final bad = <String>[];
    for (final key in kUiTranslations.keys) {
      final m = kUiTranslations[key]!;
      final enVal = m['en'] ?? '';
      if (!enVal.contains(', plural,')) continue;
      for (final lang in kI18nPrimary) {
        final blocks = icuPluralBodies(m[lang] ?? '');
        for (final b in blocks) {
          final cases = icuCases(b);
          if (lang == 'pl') {
            for (final need in ['one', 'few', 'many', 'other']) {
              if (!cases.contains(need)) bad.add('$key pl missing $need');
            }
          } else {
            for (final need in ['one', 'other']) {
              if (!cases.contains(need)) bad.add('$key $lang missing $need');
            }
          }
        }
      }
    }
    expect(bad, isEmpty, reason: bad.take(30).join('\n'));
  });

  test('d) TR/PL values are not EN copies unless allowlisted', () {
    final bad = <String>[];
    for (final key in kUiTranslations.keys) {
      final m = kUiTranslations[key]!;
      final en = (m['en'] ?? '').trim();
      if (en.isEmpty) continue;
      for (final lang in ['tr', 'pl']) {
        final v = (m[lang] ?? '').trim();
        if (v != en) continue;
        if (allowlistedValue(v, allow)) continue;
        bad.add('$key $lang == EN: $v');
      }
    }
    expect(bad, isEmpty, reason: '${bad.length} EN copies\n${bad.take(25).join('\n')}');
  });

  test('e) TR/PL values do not contain English stop words unless allowlisted', () {
    final bad = <String>[];
    for (final key in kUiTranslations.keys) {
      final m = kUiTranslations[key]!;
      for (final lang in ['tr', 'pl']) {
        final v = m[lang] ?? '';
        if (allowlistedValue(v, allow)) continue;
        for (final w in visibleWords(v)) {
          if (englishStopWords.contains(w)) {
            bad.add('$key $lang stop-word "$w" in: $v');
            break;
          }
        }
      }
    }
    expect(bad, isEmpty, reason: '${bad.length} hits\n${bad.take(25).join('\n')}');
  });

  test('missing-key policy: debug shows ⚠, not silent EN', () {
    final text = FFLocalizations(const Locale('tr')).getText('__no_such_i18n_key__');
    expect(text, '⚠ __no_such_i18n_key__');
  });
}
