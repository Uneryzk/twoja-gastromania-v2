import 'package:flutter/material.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_special_order.dart';

/// Free quality signal chips — only true signals are shown.
class SoQualityChips extends StatelessWidget {
  const SoQualityChips({super.key, required this.request});
  final TGSpecialRequest request;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final chips = <(IconData, String)>[
      if (request.budgetGiven) (Icons.payments_outlined, 'Budget given'),
      if (request.drawingAttached) (Icons.architecture_outlined, 'Drawing attached'),
      if (request.phoneVerified) (Icons.verified_user_outlined, 'Phone verified'),
      if (request.companyNip) (Icons.badge_outlined, 'Company (NIP)'),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final c in chips)
          Semantics(
            label: c.$2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.alternate,
                borderRadius: BorderRadius.circular(TGRadius.pill),
                border: Border.all(color: theme.tertiary),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(c.$1, size: 14, color: theme.primary),
                  const SizedBox(width: 4),
                  Text(c.$2, style: theme.bodySmall.override(fontWeight: FontWeight.w700, fontSize: 11)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
