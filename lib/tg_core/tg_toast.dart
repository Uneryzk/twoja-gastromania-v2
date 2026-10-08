import 'package:flutter/material.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';

/// Shows a short, floating toast (a styled [SnackBar]) and replaces any toast
/// that is still visible, so rapid repeated actions never queue up.
///
/// Used for lightweight confirmations such as "Number copied".
void showTGToast(
  BuildContext context,
  String message, {
  IconData icon = Icons.check_circle_rounded,
  Color iconColor = TGColors.cta,
  SnackBarAction? action,
  Duration duration = const Duration(milliseconds: 1800),
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  // A floating SnackBar may use either `width` or `margin`, never both.
  final wide = MediaQuery.sizeOf(context).width >= 640;

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        width: wide ? 360 : null,
        margin: wide ? null : const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: duration,
        persist: false,
        elevation: 8,
        backgroundColor: TGColors.surfaceHover,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TGRadius.input),
          side: const BorderSide(color: TGColors.border),
        ),
        action: action,
        content: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: TGColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
}
