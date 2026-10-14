import 'package:flutter/widgets.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';

/// Chrome copy that services persist instead of an English sentence.
/// The UI resolves with the active (or recipient) locale.
@immutable
class LocalizedMessage {
  const LocalizedMessage(this.key, [this.args = const {}]);

  final String key;
  final Map<String, String> args;

  String resolve([Locale locale = const Locale('en')]) => FFLocalizations(locale).getText(key, args);

  String resolveOf(BuildContext context) => context.t(key, args);

  Map<String, Object> toRecord() => {'key': key, 'args': args};

  factory LocalizedMessage.fromRecord(Map<String, Object?> json) {
    final rawArgs = json['args'];
    return LocalizedMessage(
      json['key'] as String? ?? '',
      rawArgs is Map ? rawArgs.map((k, v) => MapEntry('$k', '$v')) : const {},
    );
  }

  @override
  String toString() => 'LocalizedMessage($key, $args)';
}
