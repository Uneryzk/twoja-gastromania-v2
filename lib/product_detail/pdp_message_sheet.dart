import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/login/login_widget.dart' show LoginPageWidget;
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_inline_translate.dart';
import 'package:twoja_gastromania/tg_components/tg_product_card.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_message.dart';
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
  final _scroll = ScrollController();
  String? _blocked;
  Timer? _demoReply;
  bool _demoQueued = false;

  @override
  void initState() {
    super.initState();
    MessagingService.instance.addListener(_onSvc);
    MessagingService.instance.ensureLoaded();
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToEnd());
  }

  @override
  void dispose() {
    _demoReply?.cancel();
    MessagingService.instance.removeListener(_onSvc);
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onSvc() {
    if (!mounted) return;
    final auth = context.read<FakeAuthState>();
    final thread = _threadOf(auth);
    if (thread != null && thread.unreadFor(auth.userId) > 0) {
      MessagingService.instance.markRead(thread.id, auth.userId);
    }
    setState(() {});
    _jumpToEnd();
  }

  TGChatThread? _threadOf(FakeAuthState auth) {
    if (!auth.isLoggedIn) return null;
    for (final t in MessagingService.instance.threads) {
      if (t.listingId == widget.product.id && (t.buyerId == auth.userId || t.sellerId == auth.userId)) {
        return t;
      }
    }
    return null;
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
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
    if (!result.ok) return;
    _text.clear();
    setState(() => _blocked = null);
    _queueDemoReply(auth);
  }

  void _queueDemoReply(FakeAuthState auth) {
    if (tgInWidgetTest() || _demoQueued) return;
    if (auth.userId == widget.product.seller.id) return;
    _demoQueued = true;
    _demoReply?.cancel();
    _demoReply = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      MessagingService.instance.send(
        product: widget.product,
        senderId: widget.product.seller.id,
        senderName: widget.product.seller.name,
        body: context.t('ui_demo_seller_reply'),
      );
    });
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
            key: const Key('pdp-chat-sheet'),
            height: h * 0.72,
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
                      : _ChatBody(
                          thread: _threadOf(auth),
                          userId: auth.userId,
                          text: _text,
                          scroll: _scroll,
                          blocked: _blocked,
                          onQuick: (v) => setState(() {
                            _text.text = v;
                            _blocked = null;
                          }),
                          onSend: _send,
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

class _ChatBody extends StatelessWidget {
  const _ChatBody({
    required this.thread,
    required this.userId,
    required this.text,
    required this.scroll,
    required this.blocked,
    required this.onQuick,
    required this.onSend,
  });

  final TGChatThread? thread;
  final String userId;
  final TextEditingController text;
  final ScrollController scroll;
  final String? blocked;
  final ValueChanged<String> onQuick;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final messages = thread?.messages ?? const <TGChatMessage>[];
    final chatting = messages.isNotEmpty;
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            itemCount: messages.length,
            itemBuilder: (context, i) {
              final m = messages[i];
              final mine = m.senderId == userId;
              return Align(
                alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  constraints: const BoxConstraints(maxWidth: 280),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: mine ? theme.primary.withValues(alpha: 0.18) : theme.alternate,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TGInlineTranslate(text: m.body, style: theme.bodyMedium, compact: true),
                      const SizedBox(height: 4),
                      Text(
                        '${m.timestamp.hour.toString().padLeft(2, '0')}:${m.timestamp.minute.toString().padLeft(2, '0')}',
                        style: theme.bodySmall.override(fontSize: 11, color: theme.secondaryText),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final key in const ['ui_quick_available', 'ui_quick_price', 'ui_quick_pickup', 'ui_quick_shipping'])
                ActionChip(
                  key: Key('pdp-quick-$key'),
                  label: Text(context.t(key)),
                  onPressed: () => onQuick(context.t(key)),
                ),
            ],
          ),
        ),
        if (blocked != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(blocked!, key: const Key('pdp-message-blocked'), style: const TextStyle(color: TGColors.error, fontWeight: FontWeight.w700)),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: chatting
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('pdp-message-field'),
                        controller: text,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(hintText: context.t('ui_message_hint')),
                        onSubmitted: (_) => onSend(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TGButton(
                      key: const Key('pdp-message-send'),
                      onPressed: onSend,
                      label: context.t('ui_send'),
                      icon: Icons.send,
                      height: 44,
                      borderRadius: BorderRadius.circular(TGRadius.pill),
                    ),
                  ],
                )
              : Column(
                  children: [
                    TextField(
                      key: const Key('pdp-message-field'),
                      controller: text,
                      minLines: 4,
                      maxLines: 6,
                      decoration: InputDecoration(hintText: context.t('ui_message_hint')),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: TGButton(
                        key: const Key('pdp-message-send'),
                        onPressed: onSend,
                        label: context.t('ui_send'),
                        icon: Icons.send,
                        height: 48,
                        borderRadius: BorderRadius.circular(TGRadius.pill),
                      ),
                    ),
                  ],
                ),
        ),
      ],
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
