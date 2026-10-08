import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/login/login_widget.dart' show LoginPageWidget;
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_product_card.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_services/messaging_service.dart';

Future<void> showPdpMessageSheet(BuildContext context, TGProduct product, {String? initialText}) {
  TGAnalytics.track('message_click', TGAnalytics.listingProps(product));
  final wide = MediaQuery.sizeOf(context).width >= TGBreakpoints.phone;
  if (wide) {
    final auth = context.read<FakeAuthState>();
    if (!auth.isLoggedIn) {
      return showModalBottomSheet<void>(
        context: context,
        backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (ctx) => SizedBox(height: 280, child: _LoginStep(onLogin: auth.logIn)),
      );
    }
    final thread = MessagingService.instance.ensureThread(
      product: product,
      senderId: auth.userId,
      senderName: FakeAuthState.mockOwnerSeller.name,
    );
    MessagingService.instance.openDock(threadId: thread.id, inbox: true, draft: initialText ?? '', readerId: auth.userId);
    return Future<void>.value();
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (ctx) => _MessageSheet(product: product, initialText: initialText),
  );
}

class _MessageSheet extends StatefulWidget {
  const _MessageSheet({required this.product, this.initialText});
  final TGProduct product;
  final String? initialText;

  @override
  State<_MessageSheet> createState() => _MessageSheetState();
}

class _MessageSheetState extends State<_MessageSheet> {
  late final TextEditingController _text = TextEditingController(text: widget.initialText ?? '');
  String? _blocked;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_text.text.trim().isEmpty) return;
    final auth = context.read<FakeAuthState>();
    final result = MessagingService.instance.send(
      product: widget.product,
      senderId: auth.userId,
      senderName: FakeAuthState.mockOwnerSeller.name,
      body: _text.text,
    );
    if (result.blocked) {
      setState(() => _blocked = context.t('ui_message_blocked'));
      return;
    }
    if (!result.ok || result.threadId == null) return;
    if (!mounted) return;
    Navigator.pop(context);
    TGNav.messages(context, threadId: result.threadId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final auth = context.watch<FakeAuthState>();
    final h = MediaQuery.sizeOf(context).height;
    final insets = MediaQuery.viewInsetsOf(context);

    return AnimatedPadding(
      duration: tgAnim(context, const Duration(milliseconds: 250)),
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: theme.secondaryBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: SizedBox(
            height: h * 0.62,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: theme.tertiary, borderRadius: BorderRadius.circular(99)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 56,
                          height: 42,
                          child: widget.product.imageUrl.isEmpty
                              ? ColoredBox(color: theme.alternate)
                              : Image.asset(widget.product.imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => ColoredBox(color: theme.alternate)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.product.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
                            Text(
                              widget.product.price == null ? context.t('ui_ask_price') : formatPln(widget.product.price!),
                              style: theme.bodySmall.override(color: theme.secondaryText, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close), tooltip: context.t('ui_close')),
                    ],
                  ),
                ),
                Divider(height: 1, color: theme.tertiary),
                Expanded(
                  child: !auth.isLoggedIn
                      ? _LoginStep(onLogin: auth.logIn)
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final key in const ['ui_quick_available', 'ui_quick_price', 'ui_quick_pickup', 'ui_quick_shipping'])
                                  ActionChip(
                                    key: Key('pdp-quick-$key'),
                                    label: Text(context.t(key)),
                                    onPressed: () => setState(() {
                                      _text.text = context.t(key);
                                      _blocked = null;
                                    }),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              key: const Key('pdp-message-field'),
                              controller: _text,
                              minLines: 5,
                              maxLines: 8,
                              decoration: InputDecoration(hintText: context.t('ui_message_hint')),
                            ),
                            if (_blocked != null) ...[
                              const SizedBox(height: 10),
                              Text(_blocked!, key: const Key('pdp-message-blocked'), style: const TextStyle(color: TGColors.error, fontWeight: FontWeight.w700)),
                            ],
                          ],
                        ),
                ),
                if (auth.isLoggedIn)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: TGButton(
                        key: const Key('pdp-message-send'),
                        onPressed: _send,
                        label: context.t('ui_send'),
                        icon: Icons.send,
                        height: 48,
                        borderRadius: BorderRadius.circular(TGRadius.pill),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginStep extends StatelessWidget {
  const _LoginStep({required this.onLogin});
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Icon(Icons.lock_outline, size: 40, color: theme.primary),
          const SizedBox(height: 12),
          Text(context.t('ui_login_required'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(context.t('ui_login_to_message'), textAlign: TextAlign.center, style: theme.bodyMedium.override(color: theme.secondaryText)),
          const SizedBox(height: 20),
          TGButton(
            onPressed: onLogin,
            label: context.t('ui_login'),
            icon: Icons.person,
            height: 48,
            borderRadius: BorderRadius.circular(TGRadius.pill),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.goNamed(LoginPageWidget.routeName);
            },
            child: Text(context.t('ui_login')),
          ),
        ],
      ),
    );
  }
}
