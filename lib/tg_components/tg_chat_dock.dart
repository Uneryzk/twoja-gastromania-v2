import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_inline_translate.dart';
import 'package:twoja_gastromania/tg_components/tg_product_card.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_message.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_services/messaging_service.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';

/// LinkedIn-style messaging windows, pinned to the bottom-right on desktop.
class TGChatDock extends StatelessWidget {
  const TGChatDock({super.key});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= TGBreakpoints.phone;
    if (!wide) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: MessagingService.instance,
      builder: (context, _) {
        final svc = MessagingService.instance;
        if (!svc.dockVisible) return const SizedBox.shrink();
        return _DockLayer(key: ValueKey('${svc.dockThreadId}|${svc.dockDraft}|${svc.dockMinimized}'));
      },
    );
  }
}

class _DockLayer extends StatefulWidget {
  const _DockLayer({super.key});

  @override
  State<_DockLayer> createState() => _DockLayerState();
}

class _DockLayerState extends State<_DockLayer> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  String? _blocked;

  @override
  void initState() {
    super.initState();
    final draft = MessagingService.instance.dockDraft;
    if (draft.isNotEmpty) _text.text = draft;
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final auth = context.watch<FakeAuthState>();
    final svc = MessagingService.instance;
    final h = MediaQuery.sizeOf(context).height;
    final paneH = (h * 0.52).clamp(380.0, 520.0);

    if (svc.dockMinimized) {
      return Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 16, bottom: 16),
          child: Material(
            color: theme.secondaryBackground,
            elevation: 12,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              key: const Key('chat-dock-restore'),
              onTap: svc.restoreDock,
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 280,
                height: 48,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Icon(Icons.chat_bubble, color: theme.primary, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(context.t('ui_messages'), style: theme.titleSmall.override(fontWeight: FontWeight.w800))),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: svc.closeDock,
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: context.t('ui_close'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final thread = svc.dockThreadId == null ? null : svc.byId(svc.dockThreadId!);

    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 16, bottom: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (thread != null) ...[
              _ChatWindow(
                height: paneH,
                thread: thread,
                userId: auth.userId,
                text: _text,
                scroll: _scroll,
                blocked: _blocked,
                onSend: () => _send(auth, thread),
                onQuick: (v) => setState(() {
                  _text.text = v;
                  _blocked = null;
                }),
                onReport: () => _report(auth, thread),
              ),
              const SizedBox(width: 8),
            ],
            if (svc.dockInboxOpen)
              _InboxWindow(
                height: paneH,
                userId: auth.userId,
                selectedId: svc.dockThreadId,
                onSelect: (id) {
                  svc.openDock(threadId: id, inbox: true, readerId: auth.userId);
                  setState(() => _blocked = null);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _send(FakeAuthState auth, TGChatThread thread) async {
    final product = await _productOf(thread);
    final result = MessagingService.instance.send(
      product: product,
      senderId: auth.userId,
      senderName: FakeAuthState.mockOwnerSeller.name,
      body: _text.text,
    );
    if (result.blocked) {
      setState(() => _blocked = context.t('ui_message_blocked'));
      return;
    }
    if (result.ok) {
      _text.clear();
      MessagingService.instance.dockDraft = '';
      setState(() => _blocked = null);
    }
  }

  Future<void> _report(FakeAuthState auth, TGChatThread thread) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = FlutterFlowTheme.of(ctx);
        return AlertDialog(
          backgroundColor: theme.secondaryBackground,
          title: Text(ctx.t('ui_report_conversation')),
          content: Text(ctx.t('ui_report_conversation_help')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.t('ui_cancel'))),
            TextButton(key: const Key('messages-report-confirm'), onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.t('ui_report_conversation'))),
          ],
        );
      },
    );
    if (ok == true) MessagingService.instance.reportThread(thread.id, auth.userId);
  }
}

Future<TGProduct> _productOf(TGChatThread thread) async {
  final found = await TGProductService.instance.getById(thread.listingId);
  return found ??
      TGProduct(
        id: thread.listingId,
        title: thread.listingTitle,
        price: thread.listingPrice,
        priceUnit: TGPriceUnit.oneTime,
        priceBasis: TGPriceBasis.brutto,
        negotiable: false,
        oldPrice: null,
        condition: TGCondition.used,
        listingType: TGListingType.buy,
        category: TGCategory.cookingEquipment,
        powerType: TGPowerType.electric,
        warrantyMonths: 0,
        delivery: true,
        pickup: true,
        seller: TGSeller(id: thread.sellerId, name: thread.sellerName, type: TGSellerType.private, verified: false, rating: 0),
        city: '',
        voivodeship: '',
        phone: '',
        imageUrl: thread.listingImageUrl,
        photoCount: 1,
        isPromoted: false,
        createdAt: DateTime.now(),
        listingNo: thread.listingNo,
      );
}

class _ChatWindow extends StatelessWidget {
  const _ChatWindow({
    required this.height,
    required this.thread,
    required this.userId,
    required this.text,
    required this.scroll,
    required this.blocked,
    required this.onSend,
    required this.onQuick,
    required this.onReport,
  });

  final double height;
  final TGChatThread thread;
  final String userId;
  final TextEditingController text;
  final ScrollController scroll;
  final String? blocked;
  final VoidCallback onSend;
  final ValueChanged<String> onQuick;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final svc = MessagingService.instance;
    return Material(
      key: const Key('chat-dock'),
      color: theme.secondaryBackground,
      elevation: 16,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 360,
        height: height,
        child: Column(
          children: [
            Container(
              height: 52,
              padding: const EdgeInsets.only(left: 10, right: 2),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.tertiary))),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 36,
                      height: 28,
                      child: thread.listingImageUrl.isEmpty
                          ? ColoredBox(color: theme.alternate)
                          : Image.asset(thread.listingImageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => ColoredBox(color: theme.alternate)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => context.go(thread.listingPath),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(thread.listingTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.bodySmall.override(fontWeight: FontWeight.w800)),
                          Text(
                            [
                              thread.otherPartyName(userId),
                              if (thread.listingPrice != null) formatPln(thread.listingPrice!),
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.bodySmall.override(fontSize: 11, color: theme.secondaryText),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('messages-report'),
                    tooltip: context.t('ui_report_conversation'),
                    onPressed: onReport,
                    icon: Icon(Icons.flag_outlined, size: 18, color: thread.reported ? TGColors.accent : theme.secondaryText),
                  ),
                  IconButton(
                    tooltip: context.t('ui_minimize'),
                    onPressed: svc.minimizeDock,
                    icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                  ),
                  IconButton(
                    key: const Key('chat-dock-close'),
                    tooltip: context.t('ui_close'),
                    onPressed: svc.closeChat,
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                itemCount: thread.messages.length,
                itemBuilder: (context, i) {
                  final m = thread.messages[i];
                  final mine = m.senderId == userId;
                  return Align(
                    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      constraints: const BoxConstraints(maxWidth: 260),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: mine ? theme.primary.withValues(alpha: 0.18) : theme.alternate,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: TGInlineTranslate(text: m.body, style: theme.bodySmall, compact: true),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final key in const ['ui_quick_available', 'ui_quick_price', 'ui_quick_pickup', 'ui_quick_shipping'])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          visualDensity: VisualDensity.compact,
                          label: Text(context.t(key), style: const TextStyle(fontSize: 11)),
                          onPressed: () => onQuick(context.t(key)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (blocked != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
                child: Text(blocked!, key: const Key('messages-blocked'), style: const TextStyle(color: TGColors.error, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('messages-composer'),
                      controller: text,
                      minLines: 1,
                      maxLines: 3,
                      style: theme.bodySmall,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: context.t('ui_message_hint'),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                      onSubmitted: (_) => onSend(),
                    ),
                  ),
                  IconButton(
                    key: const Key('messages-send'),
                    onPressed: onSend,
                    icon: Icon(Icons.send, color: theme.primary),
                    tooltip: context.t('ui_send'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InboxWindow extends StatelessWidget {
  const _InboxWindow({
    required this.height,
    required this.userId,
    required this.selectedId,
    required this.onSelect,
  });

  final double height;
  final String userId;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final svc = MessagingService.instance;
    final inbox = svc.inboxFor(userId);
    return Material(
      key: const Key('chat-dock-inbox'),
      color: theme.secondaryBackground,
      elevation: 16,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 300,
        height: height,
        child: Column(
          children: [
            Container(
              height: 52,
              padding: const EdgeInsets.only(left: 14, right: 2),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.tertiary))),
              child: Row(
                children: [
                  Expanded(child: Text(context.t('ui_messages'), style: theme.titleSmall.override(fontWeight: FontWeight.w800))),
                  IconButton(onPressed: svc.minimizeDock, icon: const Icon(Icons.keyboard_arrow_down, size: 20), tooltip: context.t('ui_minimize')),
                  IconButton(onPressed: svc.closeDock, icon: const Icon(Icons.close, size: 18), tooltip: context.t('ui_close')),
                ],
              ),
            ),
            Expanded(
              child: inbox.isEmpty
                  ? Center(child: Text(context.t('ui_no_messages'), style: theme.bodySmall.override(color: theme.secondaryText)))
                  : ListView.builder(
                      itemCount: inbox.length,
                      itemBuilder: (context, i) {
                        final t = inbox[i];
                        final selected = t.id == selectedId;
                        return InkWell(
                          onTap: () => onSelect(t.id),
                          child: Container(
                            color: selected ? theme.primary.withValues(alpha: 0.12) : null,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: SizedBox(
                                    width: 40,
                                    height: 32,
                                    child: t.listingImageUrl.isEmpty
                                        ? ColoredBox(color: theme.alternate)
                                        : Image.asset(t.listingImageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => ColoredBox(color: theme.alternate)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(t.listingTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.bodySmall.override(fontWeight: FontWeight.w800)),
                                      Text(t.lastMessage?.body ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.bodySmall.override(color: theme.secondaryText, fontSize: 11)),
                                    ],
                                  ),
                                ),
                                if (t.unreadFor(userId) > 0)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(color: TGColors.accent, shape: BoxShape.circle),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
