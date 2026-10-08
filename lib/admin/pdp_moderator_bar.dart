import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/admin/admin_chrome.dart';
import 'package:twoja_gastromania/admin/admin_modals.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/admin_locale_state.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';

class PdpModeratorBar extends StatelessWidget {
  const PdpModeratorBar({super.key, required this.product});
  final TGProduct product;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<FakeAuthState>();
    if (!auth.canModerate) return const SizedBox.shrink();
    return AdminL10nScope(child: Builder(builder: (context) => _bar(context, product)));
  }

  Widget _bar(BuildContext context, TGProduct product) {
    final no = product.listingNo ?? product.id;
    return Material(
      color: TGColors.adminBar,
      child: SizedBox(
        key: const Key('pdp-moderator-bar'),
        height: 36,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                '${context.t('ui_moderator_view')} · ${context.t('ui_listing_no', {'n': no})}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.go(TGAdminNav.casePath(no)),
                child: Text(context.t('ui_open_case')),
              ),
              TextButton(onPressed: () => showAdminHide(context, no), child: Text(context.t('ui_hide'))),
              TextButton(onPressed: () => showAdminRemove(context, no), child: Text(context.t('ui_remove'))),
            ],
          ),
        ),
      ),
    );
  }
}
