import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/dashboard/dashboard_nav.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_breadcrumb.dart';
import 'package:twoja_gastromania/tg_components/tg_inline_translate.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_header.dart';
import 'package:twoja_gastromania/tg_components/tg_product_card.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_no.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_message.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_services/messaging_service.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key, this.threadId});

  static const routeName = 'DashboardMessages';
  static const routePath = '/dashboard/messages';

  final String? threadId;

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  String? _selectedId;
  final _text = TextEditingController();
  final _scroll = ScrollController();
  String? _filterError;
  final _quote = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedId = widget.threadId;
    MessagingService.instance.ensureLoaded().then((_) {
      if (!mounted) return;
      final id = _selectedId;
      if (id == null) return;
      MessagingService.instance.markRead(id, context.read<FakeAuthState>().userId);
    });
  }

  @override
  void didUpdateWidget(covariant MessagesPage old) {
    super.didUpdateWidget(old);
    if (widget.threadId != old.threadId && widget.threadId != null) {
      _selectedId = widget.threadId;
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    _quote.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final auth = context.watch<FakeAuthState>();
    final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
    final pad = phone ? 16.0 : 24.0;

    return TGPageScaffold(
      body: ListenableBuilder(
        listenable: MessagingService.instance,
        builder: (context, _) {
          final inbox = MessagingService.instance.inboxFor(auth.userId);
          final selected = _selectedId == null ? null : MessagingService.instance.byId(_selectedId!);

          return Column(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1280),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(pad, 16, pad, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TGBreadcrumb(
                            items: [
                              TGBreadcrumbItem(label: context.t('ui_home'), onTap: () => TGNav.home(context)),
                              TGBreadcrumbItem(label: context.t('ui_messages')),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(context.t('ui_messages'), style: theme.headlineMedium.override(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 10),
                          const TGDashboardNav(current: TGDashboardSection.messages),
                          const SizedBox(height: 14),
                          Expanded(
                            child: phone
                                ? (selected == null
                                    ? _ThreadList(
                                        threads: inbox,
                                        userId: auth.userId,
                                        selectedId: _selectedId,
                                        onSelect: (id) => _select(id, auth.userId),
                                      )
                                    : _ChatPane(
                                        thread: selected,
                                        userId: auth.userId,
                                        text: _text,
                                        scroll: _scroll,
                                        filterError: _filterError,
                                        showBack: true,
                                        onBack: () => setState(() => _selectedId = null),
                                        onSend: () => _send(auth, selected),
                                        onReport: () => _report(auth, selected),
                                        onQuick: (v) => setState(() => _text.text = v),
                                        onShareListing: () => _shareListing(auth, selected),
                                        onQuote: () => _offer(auth, selected),
                                      ))
                                : Row(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      SizedBox(
                                        width: 340,
                                        child: _ThreadList(
                                          threads: inbox,
                                          userId: auth.userId,
                                          selectedId: _selectedId,
                                          onSelect: (id) => _select(id, auth.userId),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: selected == null
                                            ? _EmptyChat(theme: theme)
                                            : _ChatPane(
                                                thread: selected,
                                                userId: auth.userId,
                                                text: _text,
                                                scroll: _scroll,
                                                filterError: _filterError,
                                                showBack: false,
                                                onBack: () {},
                                                onSend: () => _send(auth, selected),
                                                onReport: () => _report(auth, selected),
                                                onQuick: (v) => setState(() => _text.text = v),
                                                onShareListing: () => _shareListing(auth, selected),
                                                onQuote: () => _offer(auth, selected),
                                              ),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _select(String id, String userId) {
    setState(() => _selectedId = id);
    MessagingService.instance.markRead(id, userId);
  }

  Future<void> _send(FakeAuthState auth, TGChatThread thread) async {
    final body = _text.text;
    final product = await _productOf(thread);
    if (!mounted) return;
    final result = MessagingService.instance.send(
      product: product,
      senderId: auth.userId,
      senderName: FakeAuthState.mockOwnerSeller.name,
      body: body,
    );
    if (result.blocked) {
      setState(() => _filterError = context.t('ui_message_blocked'));
      return;
    }
    if (result.ok) {
      _text.clear();
      setState(() => _filterError = null);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
    }
  }

  Future<void> _shareListing(FakeAuthState auth, TGChatThread thread) async {
    final product = await _productOf(thread);
    MessagingService.instance.send(
      product: product,
      senderId: auth.userId,
      senderName: FakeAuthState.mockOwnerSeller.name,
      body: product.detailPath,
      kind: TGMessageKind.listingLink,
      listingPath: product.detailPath,
    );
  }

  Future<void> _offer(FakeAuthState auth, TGChatThread thread) async {
    _quote.clear();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = FlutterFlowTheme.of(ctx);
        return AlertDialog(
          backgroundColor: theme.secondaryBackground,
          title: Text(ctx.t('ui_price_offer')),
          content: TextField(
            controller: _quote,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(hintText: ctx.t('ui_price_offer_hint'), suffixText: 'PLN'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.t('ui_cancel'))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.t('ui_send'))),
          ],
        );
      },
    );
    final amount = int.tryParse(_quote.text.replaceAll(RegExp(r'\D'), ''));
    if (ok != true || amount == null) return;
    final product = await _productOf(thread);
    MessagingService.instance.send(
      product: product,
      senderId: auth.userId,
      senderName: FakeAuthState.mockOwnerSeller.name,
      body: context.t('ui_price_offer_body', {'amount': '$amount'}),
      kind: TGMessageKind.priceQuote,
      quotePln: amount,
    );
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
    if (ok == true) {
      MessagingService.instance.reportThread(thread.id, auth.userId);
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
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.theme});
  final FlutterFlowTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(TGRadius.card),
        border: Border.all(color: theme.tertiary),
      ),
      child: Center(
        child: Text(context.t('ui_select_conversation'), style: theme.bodyMedium.override(color: theme.secondaryText)),
      ),
    );
  }
}

class _ThreadList extends StatelessWidget {
  const _ThreadList({
    required this.threads,
    required this.userId,
    required this.selectedId,
    required this.onSelect,
  });

  final List<TGChatThread> threads;
  final String userId;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    if (threads.isEmpty) {
      return Center(child: Text(context.t('ui_no_messages'), style: theme.bodyMedium.override(color: theme.secondaryText)));
    }
    return ListView.separated(
      key: const Key('messages-thread-list'),
      itemCount: threads.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final t = threads[i];
        final selected = t.id == selectedId;
        final unread = t.unreadFor(userId);
        return Material(
          color: selected ? theme.primary.withValues(alpha: 0.12) : theme.secondaryBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TGRadius.card),
            side: BorderSide(color: selected ? theme.primary : theme.tertiary),
          ),
          child: InkWell(
            key: Key('messages-thread-${t.id}'),
            onTap: () => onSelect(t.id),
            borderRadius: BorderRadius.circular(TGRadius.card),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 56,
                      height: 42,
                      child: t.listingImageUrl.isEmpty
                          ? ColoredBox(color: theme.alternate)
                          : Image.asset(t.listingImageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => ColoredBox(color: theme.alternate)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.listingTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.bodyMedium.override(fontWeight: FontWeight.w800)),
                        Text(t.otherPartyName(userId), maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.bodySmall.override(color: theme.secondaryText)),
                        Text(t.lastMessage?.body ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.bodySmall),
                      ],
                    ),
                  ),
                  if (unread > 0)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: TGColors.accent, borderRadius: BorderRadius.circular(99)),
                      child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ChatPane extends StatelessWidget {
  const _ChatPane({
    required this.thread,
    required this.userId,
    required this.text,
    required this.scroll,
    required this.filterError,
    required this.showBack,
    required this.onBack,
    required this.onSend,
    required this.onReport,
    required this.onQuick,
    required this.onShareListing,
    required this.onQuote,
  });

  final TGChatThread thread;
  final String userId;
  final TextEditingController text;
  final ScrollController scroll;
  final String? filterError;
  final bool showBack;
  final VoidCallback onBack;
  final VoidCallback onSend;
  final VoidCallback onReport;
  final ValueChanged<String> onQuick;
  final VoidCallback onShareListing;
  final VoidCallback onQuote;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(TGRadius.card),
        border: Border.all(color: theme.tertiary),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
            child: Row(
              children: [
                if (showBack) IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back), tooltip: context.t('ui_back')),
                Expanded(
                  child: InkWell(
                    onTap: () => context.go(thread.listingPath),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 48,
                            height: 36,
                            child: thread.listingImageUrl.isEmpty
                                ? ColoredBox(color: theme.alternate)
                                : Image.asset(thread.listingImageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => ColoredBox(color: theme.alternate)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(thread.listingTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.bodyMedium.override(fontWeight: FontWeight.w800)),
                              Text(
                                [
                                  thread.otherPartyName(userId),
                                  if (thread.listingPrice != null) formatPln(thread.listingPrice!),
                                ].join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.bodySmall.override(color: theme.secondaryText),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('messages-report'),
                  tooltip: context.t('ui_report_conversation'),
                  onPressed: onReport,
                  icon: Icon(Icons.flag_outlined, color: thread.reported ? TGColors.accent : theme.secondaryText),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.tertiary),
          Expanded(
            child: ListView.builder(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              itemCount: thread.messages.length,
              itemBuilder: (context, i) {
                final m = thread.messages[i];
                final mine = m.senderId == userId;
                return Align(
                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    constraints: const BoxConstraints(maxWidth: 420),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: mine ? theme.primary.withValues(alpha: 0.18) : theme.alternate,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (m.kind == TGMessageKind.listingLink)
                          TextButton(
                            onPressed: () => context.go(m.listingPath ?? thread.listingPath),
                            child: Text(context.t('ui_view_listing')),
                          )
                        else if (m.kind == TGMessageKind.priceQuote)
                          Text(m.body, style: theme.bodyMedium.override(fontWeight: FontWeight.w800, color: theme.primary))
                        else
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
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final key in const ['ui_quick_available', 'ui_quick_price', 'ui_quick_pickup', 'ui_quick_shipping'])
                  ActionChip(label: Text(context.t(key)), onPressed: () => onQuick(context.t(key))),
                ActionChip(label: Text(context.t('ui_share_listing')), onPressed: onShareListing),
                ActionChip(label: Text(context.t('ui_price_offer')), onPressed: onQuote),
              ],
            ),
          ),
          if (filterError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(filterError!, key: const Key('messages-blocked'), style: const TextStyle(color: TGColors.error, fontWeight: FontWeight.w700)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('messages-composer'),
                    controller: text,
                    minLines: 1,
                    maxLines: 3,
                    decoration: InputDecoration(hintText: context.t('ui_message_hint')),
                    onSubmitted: (_) => onSend(),
                  ),
                ),
                const SizedBox(width: 8),
                TGButton(
                  key: const Key('messages-send'),
                  onPressed: onSend,
                  label: context.t('ui_send'),
                  icon: Icons.send,
                  height: 40,
                  borderRadius: BorderRadius.circular(TGRadius.pill),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
