import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:twoja_gastromania/flutter_flow/tg_l10n.dart';
import 'package:twoja_gastromania/tg_core/duration_service.dart';

/// Day-only duration labels from ICU plural messages in [kUiTranslations]
/// (`dur_*` keys). Never build "N days" by string concatenation.
class DurationFormatter {
  DurationFormatter._();

  static String _message(String key, String locale) {
    final m = kUiTranslations[key];
    if (m == null) return key;
    return m[locale] ?? m[locale.split(RegExp('[_-]')).first] ?? m['en'] ?? key;
  }

  /// "14 gün" / "14 days" / "1 day" / "5 dni" / "1 dzień".
  static String days(int n, String locale) => formatIcu(_message('dur_days', locale), locale, {'count': n});

  /// Same as [days], using the widget's locale.
  static String daysOf(BuildContext context, int n) => days(n, Localizations.localeOf(context).languageCode);

  /// "13 days left", "Ends today · 6 h", "Ended 3 days ago", "Ended today".
  static String remaining(DateTime endsAt, String locale, {DateTime? now}) {
    if (DurationService.endsWithin24h(endsAt, now: now)) {
      return formatIcu(_message('dur_ends_today', locale), locale, {'hours': DurationService.hoursLeft(endsAt, now: now)});
    }
    final left = DurationService.daysLeft(endsAt, now: now);
    if (left > 0) return formatIcu(_message('dur_days_left', locale), locale, {'count': left});
    final ago = DurationService.daysAgo(endsAt, now: now);
    if (ago == 0) return formatIcu(_message('dur_ended_today', locale), locale, const {});
    return formatIcu(_message('dur_ended_ago', locale), locale, {'count': ago});
  }

  /// "{price} PLN / 14 days".
  static String pricePerPeriod(int pricePln, int days, String locale) => formatIcu(
        _message('dur_price_per', locale),
        locale,
        {'price': pricePln, 'period': DurationFormatter.days(days, locale)},
      );

  /// Minimal ICU MessageFormat: `{name}` substitution and
  /// `{name, plural, =N{..} zero{..} one{..} two{..} few{..} many{..} other{..}}`
  /// with `#` for the number. Plural categories follow CLDR rules via [Intl.pluralLogic].
  static String formatIcu(String pattern, String locale, Map<String, Object> args) {
    final out = StringBuffer();
    var i = 0;
    while (i < pattern.length) {
      final c = pattern[i];
      if (c != '{') {
        out.write(c);
        i++;
        continue;
      }
      final end = _matchingBrace(pattern, i);
      final body = pattern.substring(i + 1, end);
      out.write(_formatArgument(body, locale, args));
      i = end + 1;
    }
    return out.toString();
  }

  static int _matchingBrace(String s, int open) {
    var depth = 0;
    for (var i = open; i < s.length; i++) {
      if (s[i] == '{') depth++;
      if (s[i] == '}') {
        depth--;
        if (depth == 0) return i;
      }
    }
    throw FormatException('Unbalanced ICU braces', s, open);
  }

  static String _formatArgument(String body, String locale, Map<String, Object> args) {
    final firstComma = body.indexOf(',');
    if (firstComma < 0) return '${args[body.trim()] ?? '{$body}'}';
    final name = body.substring(0, firstComma).trim();
    final rest = body.substring(firstComma + 1);
    final secondComma = rest.indexOf(',');
    final type = (secondComma < 0 ? rest : rest.substring(0, secondComma)).trim();
    if (type != 'plural' || secondComma < 0) return '${args[name] ?? ''}';
    final value = args[name];
    final n = value is num ? value : num.tryParse('$value') ?? 0;
    final cases = _parseCases(rest.substring(secondComma + 1));
    final exact = cases['=$n'];
    final chosen = exact ??
        Intl.pluralLogic<String?>(
          n,
          locale: locale,
          zero: cases['zero'],
          one: cases['one'],
          two: cases['two'],
          few: cases['few'],
          many: cases['many'],
          other: cases['other'] ?? '',
        ) ??
        cases['other'] ??
        '';
    final withNumber = chosen.replaceAll('#', '$n');
    return formatIcu(withNumber, locale, args);
  }

  static Map<String, String> _parseCases(String s) {
    final cases = <String, String>{};
    var i = 0;
    while (i < s.length) {
      while (i < s.length && s[i].trim().isEmpty) {
        i++;
      }
      if (i >= s.length) break;
      final open = s.indexOf('{', i);
      if (open < 0) break;
      final selector = s.substring(i, open).trim();
      final close = _matchingBrace(s, open);
      cases[selector] = s.substring(open + 1, close);
      i = close + 1;
    }
    return cases;
  }
}
