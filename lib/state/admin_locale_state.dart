import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// UI language for the moderation console, independent of the public marketplace.
/// Defaults to Turkish; tests pin this to English via [reset].
class AdminLocaleState extends ChangeNotifier {
  AdminLocaleState._();
  static final AdminLocaleState instance = AdminLocaleState._();

  static const defaultCode = 'tr';
  static const supported = ['tr', 'pl', 'en'];

  String languageCode = defaultCode;

  Locale get locale => Locale(languageCode);

  void setLanguage(String code) {
    final next = supported.contains(code) ? code : defaultCode;
    if (next == languageCode) return;
    languageCode = next;
    notifyListeners();
  }

  void reset({String to = defaultCode}) {
    languageCode = supported.contains(to) ? to : defaultCode;
  }
}

/// Re-resolves [FFLocalizations] under the admin language.
class AdminL10nScope extends StatelessWidget {
  const AdminL10nScope({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final code = context.watch<AdminLocaleState>().languageCode;
    return Localizations.override(
      context: context,
      locale: Locale(code),
      child: child,
    );
  }
}
