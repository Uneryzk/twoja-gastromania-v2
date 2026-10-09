import 'package:flutter/material.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_services/messaging_service.dart';
import 'package:provider/provider.dart';

enum TGDashboardSection { listings, messages, deals }

class TGDashboardNav extends StatelessWidget {
  const TGDashboardNav({super.key, required this.current});
  final TGDashboardSection current;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final auth = context.watch<FakeAuthState>();
    return ListenableBuilder(
      listenable: MessagingService.instance,
      builder: (context, _) {
        final unread = auth.isLoggedIn ? MessagingService.instance.unreadTotal(auth.userId) : 0;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip(
              context,
              theme,
              selected: current == TGDashboardSection.listings,
              label: context.t('ui_my_listings'),
              onTap: () => TGNav.dashboardListings(context),
            ),
            _chip(
              context,
              theme,
              selected: current == TGDashboardSection.messages,
              label: context.t('ui_messages'),
              badge: unread,
              onTap: () => TGNav.messages(context),
            ),
            _chip(
              context,
              theme,
              selected: current == TGDashboardSection.deals,
              label: context.t('ui_deals'),
              onTap: () => TGNav.dashboardDeals(context),
            ),
          ],
        );
      },
    );
  }

  Widget _chip(
    BuildContext context,
    FlutterFlowTheme theme, {
    required bool selected,
    required String label,
    required VoidCallback onTap,
    int badge = 0,
  }) {
    return ActionChip(
      onPressed: onTap,
      backgroundColor: selected ? theme.primary.withValues(alpha: 0.18) : theme.alternate,
      side: BorderSide(color: selected ? theme.primary : theme.tertiary),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: theme.bodySmall.override(fontWeight: FontWeight.w800, color: selected ? theme.primary : theme.primaryText)),
          if (badge > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: TGColors.accent, borderRadius: BorderRadius.circular(99)),
              child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ],
        ],
      ),
    );
  }
}
