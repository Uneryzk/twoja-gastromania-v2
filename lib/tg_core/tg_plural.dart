import 'package:flutter/widgets.dart';
import 'package:twoja_gastromania/flutter_flow/tg_l10n.dart';
import 'package:twoja_gastromania/tg_core/duration_formatter.dart';

/// ICU plural helper aligned with [DurationFormatter].
///
/// Polish uses one/few/many/other; Turkish and English use one/other.
abstract final class TGPlural {
  /// Formats an ICU `{count, plural, ...}` pattern already stored in l10n.
  static String icu(String pattern, String locale, Map<String, Object> args) =>
      DurationFormatter.formatIcu(pattern, locale, args);

  /// Looks up [key] for [locale] and formats it as ICU (does not go through getText).
  static String ofKey(String key, String locale, Map<String, Object> args) {
    final code = locale.split(RegExp('[_-]')).first;
    final m = kUiTranslations[key];
    final raw = m?[code] ?? m?['en'] ?? key;
    return DurationFormatter.formatIcu(raw, code, args);
  }

  static String of(BuildContext context, String key, Map<String, Object> args) =>
      ofKey(key, Localizations.localeOf(context).languageCode, args);

  /// "N listings" / "N ogłoszeń" / "N ilan" via `ui_listing_count`.
  static String listings(int n, String locale) => ofKey('ui_listing_count', locale, {'count': n});

  static String listingsOf(BuildContext context, int n) =>
      listings(n, Localizations.localeOf(context).languageCode);
}
