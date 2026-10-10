import 'package:flutter/material.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_special_order.dart';

class SoStatusChip extends StatelessWidget {
  const SoStatusChip({super.key, required this.status, this.quoteCount = 0, this.rejectReason});

  final TGSpecialRequestStatus status;
  final int quoteCount;
  final String? rejectReason;

  @override
  Widget build(BuildContext context) {
    final (label, icon, fg, bg, outline) = switch (status) {
      TGSpecialRequestStatus.draft => (context.t('ui_so_status_draft'), Icons.edit_outlined, const Color(0xFFBDBDBD), const Color(0xFF2A2A2A), false),
      TGSpecialRequestStatus.held => (context.t('ui_so_status_check'), Icons.shield_moon_outlined, const Color(0xFFFFB74D), const Color(0x332A1F00), false),
      TGSpecialRequestStatus.open || TGSpecialRequestStatus.quoted => (
          context.t('ui_so_status_open', {'n': '$quoteCount'}),
          Icons.hourglass_top_outlined,
          TGColors.cta,
          Colors.transparent,
          true,
        ),
      TGSpecialRequestStatus.awarded => (context.t('ui_so_status_awarded'), Icons.check_circle_outline, TGColors.cta, const Color(0x2226E6B3), false),
      TGSpecialRequestStatus.closed => (context.t('ui_so_status_closed'), Icons.lock_outline, const Color(0xFFBDBDBD), const Color(0xFF2A2A2A), false),
      TGSpecialRequestStatus.expired => (context.t('ui_so_status_expired'), Icons.timer_off_outlined, const Color(0xFFBDBDBD), const Color(0xFF2A2A2A), false),
      TGSpecialRequestStatus.rejected => (context.t('ui_so_status_rejected'), Icons.block, const Color(0xFFFF5252), Colors.transparent, true),
    };

    return Tooltip(
      message: rejectReason ?? label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(TGRadius.pill),
          border: outline ? Border.all(color: fg, width: 1.4) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
