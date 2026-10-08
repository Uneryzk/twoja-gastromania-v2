import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:url_launcher/url_launcher.dart';

/// True on devices that can place a phone call from the app.
bool get _canDial =>
    !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

/// Copies [phone] to the clipboard and confirms with a toast ("Number copied").
///
/// The classifieds model has no in-platform checkout, so the seller's number is
/// the primary contact channel. Copying is the same on every platform; on phones
/// the toast additionally offers a one-tap "CALL" action.
Future<void> copyPhoneNumber(BuildContext context, String phone) async {
  try {
    await Clipboard.setData(ClipboardData(text: phone));
  } catch (e) {
    debugPrint('Clipboard write failed: $e');
    if (context.mounted) {
      showTGToast(context, 'Could not copy the number', icon: Icons.error_outline, iconColor: TGColors.error);
    }
    return;
  }
  if (!context.mounted) return;

  final dial = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  showTGToast(
    context,
    'Number copied',
    action: _canDial && dial.isNotEmpty
        ? SnackBarAction(
            label: 'CALL',
            textColor: TGColors.cta,
            onPressed: () => launchUrl(Uri(scheme: 'tel', path: dial)),
          )
        : null,
  );
}

/// Copies arbitrary text (e-mail, address, ...) with a custom confirmation.
Future<void> copyTextWithToast(BuildContext context, String text, {required String message}) async {
  try {
    await Clipboard.setData(ClipboardData(text: text));
  } catch (e) {
    debugPrint('Clipboard write failed: $e');
    return;
  }
  if (context.mounted) showTGToast(context, message);
}

/// Opens [url] in the platform browser/app, falling back to a toast.
Future<bool> openExternalUrl(BuildContext context, Uri url, {String failMessage = 'Could not open the link'}) async {
  try {
    final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (ok) return true;
  } catch (e) {
    debugPrint('launchUrl failed for $url: $e');
  }
  if (context.mounted) {
    showTGToast(context, failMessage, icon: Icons.error_outline, iconColor: TGColors.error);
  }
  return false;
}
