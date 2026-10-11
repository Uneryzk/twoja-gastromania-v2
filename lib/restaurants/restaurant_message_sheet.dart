import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/login/login_widget.dart' show LoginPageWidget;
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_smart_image.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_restaurant_listing.dart';
import 'package:twoja_gastromania/tg_services/restaurant_service.dart';

const _kQuick = [
  'Can I see the lease?',
  "Is the landlord's consent confirmed?",
  'Can we arrange a viewing?',
];

Future<void> showRestaurantMessageSheet(BuildContext context, RestaurantListing listing) async {
  TGAnalytics.track('resto_message_click', {'listingNo': listing.listingNo});
  final auth = context.read<FakeAuthState>();
  if (!auth.isLoggedIn) {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(ctx.t('ui_login_required'), style: FlutterFlowTheme.of(ctx).titleMedium.override(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text('Sign in to send a message. Calling does not require login.', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            TGButton(
              onPressed: () {
                Navigator.pop(ctx);
                ctx.goNamed(LoginPageWidget.routeName);
              },
              label: ctx.t('ui_login'),
              height: 44,
              borderRadius: BorderRadius.circular(TGRadius.pill),
            ),
          ],
        ),
      ),
    );
    return;
  }

  final wide = MediaQuery.sizeOf(context).width >= TGBreakpoints.phone;
  if (wide) {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black54,
      transitionDuration: tgAnim(context, const Duration(milliseconds: 200)),
      pageBuilder: (ctx, _, __) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
          child: Material(
            borderRadius: BorderRadius.circular(16),
            color: FlutterFlowTheme.of(ctx).secondaryBackground,
            child: _RestoMessageBody(listing: listing),
          ),
        ),
      ),
    );
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => FractionallySizedBox(
      heightFactor: 0.9,
      child: Material(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        color: FlutterFlowTheme.of(ctx).secondaryBackground,
        child: _RestoMessageBody(listing: listing),
      ),
    ),
  );
}

class _RestoMessageBody extends StatefulWidget {
  const _RestoMessageBody({required this.listing});
  final RestaurantListing listing;

  @override
  State<_RestoMessageBody> createState() => _RestoMessageBodyState();
}

class _RestoMessageBodyState extends State<_RestoMessageBody> {
  final _text = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = _text.text.trim();
    if (t.isEmpty || t.length > 1000 || _sending) return;
    setState(() => _sending = true);
    final auth = context.read<FakeAuthState>();
    final count = !auth.role.isStaff && auth.userId != widget.listing.ownerId;
    RestaurantService.instance.recordContact(
      listingId: widget.listing.id,
      sessionKey: auth.isLoggedIn ? auth.userId : 'anon',
      count: count,
    );
    TGAnalytics.track('resto_message_sent', {'listingNo': widget.listing.listingNo, 'len': t.length});
    if (!mounted) return;
    Navigator.pop(context);
    showTGToast(context, 'Message sent');
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final r = widget.listing;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Row(
            children: [
              Expanded(child: Text('Send message', style: theme.titleMedium.override(fontWeight: FontWeight.w900))),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 64,
                      height: 48,
                      child: TGSmartImage(url: r.imageUrl, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text('No. ${r.listingNo} · ${r.city}', style: theme.bodySmall.override(color: theme.secondaryText)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final q in _kQuick)
                    ActionChip(
                      label: Text(q, style: const TextStyle(fontSize: 12)),
                      onPressed: () => setState(() {
                        _text.text = q;
                        _text.selection = TextSelection.collapsed(offset: q.length);
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _text,
                maxLength: 1000,
                maxLines: 6,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Write your message…',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: TGButton(
            onPressed: _text.text.trim().isEmpty ? null : _send,
            label: 'Send',
            height: 48,
            borderRadius: BorderRadius.circular(TGRadius.pill),
          ),
        ),
      ],
    );
  }
}
