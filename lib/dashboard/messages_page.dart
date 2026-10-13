import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/dashboard/dash2_widgets.dart';
import 'package:twoja_gastromania/dashboard/dashboard_nav.dart';
import 'package:twoja_gastromania/deals/sold_flow_sheet.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_breadcrumb.dart';
import 'package:twoja_gastromania/tg_components/tg_inline_translate.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_header.dart';
import 'package:twoja_gastromania/tg_components/tg_product_card.dart';
import 'package:twoja_gastromania/tg_components/tg_watermarked_image.dart';
import 'package:twoja_gastromania/tg_models/tg_watermark.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_no.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_message.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_services/messaging_service.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';

/// Bundled sample photos offered by "Attach photo" (no device picker in this build).
const kTGMessageDemoPhotos = [
  'assets/images/espresso-makinesi.jpeg',
  'assets/images/piec-konwekcyjno-parowy.jpeg',
  'assets/images/szafa-chlodnicza-700l.jpeg',
  'assets/images/planet-mikser.jpeg',
];

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key, this.threadId});

  static const routeName = 'DashboardMessages';
  static const routePath = '/dashboard/messages';

  /// Context panel (300 px) sits beside the chat from this width; below it
  /// opens from the "Details" button.
  static const contextPanelMinWidth = 1100.0;
  static const listWidth = 340.0;
  static const contextWidth = 300.0;

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
  bool _archived = false;
  final List<TGMessageAttachment> _pending = [];

  @override
  void initState() {
    super.initState();
    _selectedId = widget.threadId;
    MessagingService.instance.ensureLoaded().then((_) {
      if (!mounted) return;
      final id = _selectedId;
      if (id == null) return;
      MessagingService.instance.markRead(id, context.read<FakeAuthState>().userId);
      TGAnalytics.track('msg_open', {'threadId': id, 'source': 'link'});
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
    final width = MediaQuery.sizeOf(context).width;
    final phone = width < TGBreakpoints.phone;
    final withContext = width >= MessagesPage.contextPanelMinWidth;
    final pad = phone ? 16.0 : 24.0;

    return TGPageScaffold(
      body: ListenableBuilder(
        listenable: MessagingService.instance,
        builder: (context, _) {
          final svc = MessagingService.instance;
          final inbox = svc.inboxFor(auth.userId, archived: _archived);
          final selected = _selectedId == null ? null : svc.byId(_selectedId!);

          Widget list() => _ThreadList(
                threads: inbox,
                userId: auth.userId,
                selectedId: _selectedId,
                archived: _archived,
                onArchivedChanged: (v) => setState(() => _archived = v),
                onSelect: (id) => _select(id, auth.userId),
              );

          Widget chat(TGChatThread t, {required bool showBack}) => _ChatPane(
                thread: t,
                userId: auth.userId,
                text: _text,
                scroll: _scroll,
                filterError: _filterError,
                showBack: showBack,
                pending: _pending,
                blocked: svc.hasBlocked(auth.userId, t.otherPartyId(auth.userId)),
                onBack: () => setState(() => _selectedId = null),
                onSend: () => _send(auth, t),
                onReport: () => _report(auth, t),
                onQuick: (v) => setState(() => _text.text = v),
                onShareListing: () => _shareListing(auth, t),
                onQuote: () => _offer(auth, t),
                onAttach: () => _attach(),
                onRemovePending: (a) => setState(() => _pending.remove(a)),
                onTemplates: () => _templates(auth),
                onUnblock: () => svc.setBlocked(auth.userId, t.otherPartyId(auth.userId), false),
                onDetails: withContext ? null : () => _showContextSheet(auth, t),
              );

          return Column(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1280 + 48),
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
                          Semantics(
                            header: true,
                            child: Text(context.t('ui_messages'), style: theme.headlineMedium.override(fontWeight: FontWeight.w900)),
                          ),
                          const SizedBox(height: 10),
                          const TGDashboardNav(current: TGDashboardSection.messages),
                          const SizedBox(height: 14),
                          Expanded(
                            child: phone
                                ? (selected == null ? list() : chat(selected, showBack: true))
                                : Row(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      SizedBox(width: MessagesPage.listWidth, child: list()),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: selected == null ? _EmptyChat(theme: theme) : chat(selected, showBack: false),
                                      ),
                                      if (withContext && selected != null) ...[
                                        const SizedBox(width: 12),
                                        SizedBox(
                                          width: MessagesPage.contextWidth,
                                          child: _ContextPanel(
                                            thread: selected,
                                            userId: auth.userId,
                                            onMarkSold: () => _markSold(auth, selected),
                                            onArchive: () => _toggleArchive(auth, selected),
                                            onReport: () => _report(auth, selected),
                                            onBlock: () => _toggleBlock(auth, selected),
                                          ),
                                        ),
                                      ],
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
    setState(() {
      _selectedId = id;
      _filterError = null;
      _pending.clear();
    });
    MessagingService.instance.markRead(id, userId);
    TGAnalytics.track('msg_open', {'threadId': id, 'source': 'list'});
  }

  Future<void> _send(FakeAuthState auth, TGChatThread thread) async {
    final body = _text.text;
    final product = await _productOf(thread);
    if (!mounted) return;
    final result = MessagingService.instance.send(
      product: product,
      senderId: auth.userId,
      senderName: auth.userId == thread.buyerId ? thread.buyerName : thread.sellerName,
      body: body,
      attachments: List.of(_pending),
    );
    if (!result.ok) {
      final reason = result.reason ?? (result.blocked ? 'ui_message_blocked' : null);
      if (reason != null) setState(() => _filterError = context.t(reason));
      return;
    }
    _text.clear();
    setState(() {
      _filterError = null;
      _pending.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _attach() async {
    if (_pending.length >= MessagingLimits.maxAttachments) {
      setState(() => _filterError = context.t('msg_err_attach_count'));
      return;
    }
    final asset = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: TGColors.surface,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ctx.t('msg_attach_title'), style: FlutterFlowTheme.of(ctx).titleSmall.override(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(
                ctx.t('msg_attach_rules', {'n': '${MessagingLimits.maxAttachments}', 'mb': '${MessagingLimits.maxAttachmentBytes ~/ (1024 * 1024)}'}),
                style: FlutterFlowTheme.of(ctx).bodySmall,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < kTGMessageDemoPhotos.length; i++)
                    InkWell(
                      key: Key('messages-attach-pick-$i'),
                      onTap: () => Navigator.pop(ctx, kTGMessageDemoPhotos[i]),
                      child: Semantics(
                        button: true,
                        label: ctx.t('msg_attach_pick_sem', {'n': '${i + 1}'}),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(kTGMessageDemoPhotos[i], width: 84, height: 64, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (asset == null || !mounted) return;
    final data = await rootBundle.load(asset);
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final raw = TGMessageAttachment(
      id: 'att_${DateTime.now().microsecondsSinceEpoch}',
      fileName: asset.split('/').last,
      mimeType: 'image/jpeg',
      sizeBytes: bytes.length,
      bytes: bytes,
    );
    final prepared = MessagingService.instance.prepareAttachments([..._pending, raw]);
    if (!mounted) return;
    if (prepared.error != null) {
      setState(() => _filterError = context.t(prepared.error!));
      return;
    }
    setState(() {
      _filterError = null;
      _pending
        ..clear()
        ..addAll(prepared.files);
    });
  }

  Future<void> _templates(FakeAuthState auth) async {
    final svc = MessagingService.instance;
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TGColors.surface,
      builder: (ctx) => ListenableBuilder(
        listenable: svc,
        builder: (ctx, _) {
          final theme = FlutterFlowTheme.of(ctx);
          final items = svc.templatesFor(auth.userId);
          final full = items.length >= MessagingLimits.maxTemplates;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                key: const Key('messages-templates-sheet'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(ctx.t('msg_templates_title', {'n': '${items.length}', 'max': '${MessagingLimits.maxTemplates}'}), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  if (items.isEmpty) Text(ctx.t('msg_templates_empty'), style: theme.bodySmall),
                  for (final t in items)
                    ListTile(
                      key: Key('messages-template-${t.id}'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(t.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                      onTap: () => Navigator.pop(ctx, t.body),
                      trailing: IconButton(
                        tooltip: ctx.t('msg_template_delete'),
                        onPressed: () => svc.removeTemplate(t.id),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ),
                  const SizedBox(height: 8),
                  TGButton(
                    key: const Key('messages-template-save'),
                    onPressed: full || _text.text.trim().isEmpty
                        ? null
                        : () {
                            final body = _text.text.trim();
                            final title = body.length > 24 ? '${body.substring(0, 24)}…' : body;
                            final err = svc.addTemplate(auth.userId, title: title, body: body);
                            if (err != null) showTGToast(ctx, ctx.t(err));
                          },
                    label: full ? ctx.t('msg_err_template_limit') : ctx.t('msg_template_save'),
                    variant: TGButtonVariant.outline,
                    height: 40,
                    borderRadius: BorderRadius.circular(TGRadius.pill),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (picked != null && mounted) setState(() => _text.text = picked);
  }

  Future<void> _markSold(FakeAuthState auth, TGChatThread thread) async {
    final product = await _productOf(thread);
    if (!mounted) return;
    TGAnalytics.track('msg_mark_sold', {'threadId': thread.id});
    MessagingService.instance.markSoldTo(thread.id);
    await showSoldFlow(context, product, mode: SoldFlowMode.markSold, buyerId: thread.buyerId);
  }

  void _toggleArchive(FakeAuthState auth, TGChatThread thread) {
    final archive = !thread.isArchivedFor(auth.userId);
    MessagingService.instance.setArchived(thread.id, auth.userId, archive);
    if (archive) setState(() => _selectedId = null);
    showTGToast(
      context,
      context.t(archive ? 'msg_archived' : 'msg_unarchived'),
      action: archive
          ? SnackBarAction(label: context.t('ui_undo'), onPressed: () => MessagingService.instance.setArchived(thread.id, auth.userId, false))
          : null,
    );
  }

  Future<void> _toggleBlock(FakeAuthState auth, TGChatThread thread) async {
    final svc = MessagingService.instance;
    final other = thread.otherPartyId(auth.userId);
    if (svc.hasBlocked(auth.userId, other)) {
      svc.setBlocked(auth.userId, other, false);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FlutterFlowTheme.of(ctx).secondaryBackground,
        title: Text(ctx.t('msg_block_title', {'name': thread.otherPartyName(auth.userId)})),
        content: Text(ctx.t('msg_block_help')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.t('ui_cancel'))),
          TextButton(key: const Key('messages-block-confirm'), onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.t('msg_block'))),
        ],
      ),
    );
    if (ok == true) svc.setBlocked(auth.userId, other, true);
  }

  void _showContextSheet(FakeAuthState auth, TGChatThread thread) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TGColors.surface,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.85,
        child: ListenableBuilder(
          listenable: MessagingService.instance,
          builder: (ctx, _) => _ContextPanel(
            thread: thread,
            userId: auth.userId,
            onMarkSold: () {
              Navigator.pop(ctx);
              _markSold(auth, thread);
            },
            onArchive: () {
              Navigator.pop(ctx);
              _toggleArchive(auth, thread);
            },
            onReport: () {
              Navigator.pop(ctx);
              _report(auth, thread);
            },
            onBlock: () => _toggleBlock(auth, thread),
          ),
        ),
      ),
    );
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
    if (!mounted) return;
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
    final auth = context.read<FakeAuthState>();
    final owned = auth.ownedListings.where((p) => p.id == thread.listingId).firstOrNull;
    if (owned != null) return owned;
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
          city: thread.listingCity,
          voivodeship: '',
          phone: thread.sellerPhone ?? '',
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
    required this.archived,
    required this.onArchivedChanged,
  });

  final List<TGChatThread> threads;
  final String userId;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final bool archived;
  final ValueChanged<bool> onArchivedChanged;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              key: const Key('messages-view-inbox'),
              label: Text(context.t('msg_view_inbox')),
              selected: !archived,
              onSelected: (_) => onArchivedChanged(false),
            ),
            ChoiceChip(
              key: const Key('messages-view-archived'),
              label: Text(context.t('msg_view_archived')),
              selected: archived,
              onSelected: (_) => onArchivedChanged(true),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: threads.isEmpty
              ? Center(child: Text(context.t(archived ? 'msg_no_archived' : 'ui_no_messages'), style: theme.bodyMedium.override(color: theme.secondaryText)))
              : ListView.separated(
                  key: const Key('messages-thread-list'),
                  itemCount: threads.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final t = threads[i];
                    final selected = t.id == selectedId;
                    final unread = t.unreadFor(userId);
                    return TGFocusRing(
                      child: Semantics(
                        selected: selected,
                        label: unread > 0 ? context.t('msg_unread_sem', {'n': '$unread'}) : null,
                        child: Material(
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
                                          : WatermarkedImage(url: t.listingImageUrl, surface: TGImageSurface.listingCard, fallback: (_) => ColoredBox(color: theme.alternate)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(t.listingTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.bodyMedium.override(fontWeight: FontWeight.w800)),
                                        Text(t.otherPartyName(userId), maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.bodySmall.override(color: theme.secondaryText)),
                                        Text(_preview(context, t), maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.bodySmall),
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
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _preview(BuildContext context, TGChatThread t) {
    final m = t.lastMessage;
    if (m == null) return '';
    if (m.body.isEmpty && m.attachments.isNotEmpty) return context.t('msg_photos_n', {'n': '${m.attachments.length}'});
    return m.body;
  }
}

/// Fixed band above every conversation; never scrolls away.
class TGMessagesSafetyBand extends StatelessWidget {
  const TGMessagesSafetyBand({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Container(
        key: const Key('messages-safety-band'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: TGColors.slaAmber.withValues(alpha: 0.14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.shield_outlined, size: 16, color: TGColors.slaAmber),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.t('msg_safety_band'),
                style: FlutterFlowTheme.of(context).bodySmall.override(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
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
    required this.pending,
    required this.blocked,
    required this.onAttach,
    required this.onRemovePending,
    required this.onTemplates,
    required this.onUnblock,
    required this.onDetails,
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
  final List<TGMessageAttachment> pending;
  final bool blocked;
  final VoidCallback onAttach;
  final ValueChanged<TGMessageAttachment> onRemovePending;
  final VoidCallback onTemplates;
  final VoidCallback onUnblock;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final lastIncoming = thread.messages.lastWhere((m) => m.senderId != userId, orElse: () => _none);
    return Container(
      clipBehavior: Clip.antiAlias,
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
                                : WatermarkedImage(url: thread.listingImageUrl, surface: TGImageSurface.listingCard, fallback: (_) => ColoredBox(color: theme.alternate)),
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
                if (onDetails != null)
                  IconButton(
                    key: const Key('messages-details'),
                    tooltip: context.t('msg_details'),
                    onPressed: onDetails,
                    icon: const Icon(Icons.info_outline),
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
          const TGMessagesSafetyBand(),
          Semantics(
            key: const Key('messages-live-region'),
            liveRegion: true,
            label: identical(lastIncoming, _none)
                ? ''
                : context.t('msg_live_new', {'name': thread.otherPartyName(userId), 'body': lastIncoming.body}),
            child: const SizedBox(width: double.infinity, height: 1),
          ),
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
                        if (m.attachments.isNotEmpty) ...[
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [for (final a in m.attachments) _AttachmentThumb(attachment: a, size: 96)],
                          ),
                          if (m.body.isNotEmpty) const SizedBox(height: 6),
                        ],
                        if (m.kind == TGMessageKind.listingLink)
                          TextButton(
                            onPressed: () => context.go(m.listingPath ?? thread.listingPath),
                            child: Text(context.t('ui_view_listing')),
                          )
                        else if (m.kind == TGMessageKind.priceQuote)
                          Text(m.body, style: theme.bodyMedium.override(fontWeight: FontWeight.w800, color: theme.primary))
                        else if (m.body.isNotEmpty)
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
          if (blocked)
            Container(
              key: const Key('messages-blocked-banner'),
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
              child: Row(
                children: [
                  Expanded(child: Text(context.t('msg_you_blocked'), style: theme.bodyMedium.override(fontWeight: FontWeight.w700))),
                  TextButton(key: const Key('messages-unblock'), onPressed: onUnblock, child: Text(context.t('msg_unblock'))),
                ],
              ),
            )
          else ...[
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
                  ActionChip(
                    key: const Key('messages-templates'),
                    avatar: const Icon(Icons.bolt, size: 16),
                    label: Text(context.t('msg_templates')),
                    onPressed: onTemplates,
                  ),
                ],
              ),
            ),
            if (pending.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Wrap(
                  key: const Key('messages-pending'),
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final a in pending)
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _AttachmentThumb(attachment: a, size: 56),
                          Positioned(
                            right: -8,
                            top: -8,
                            child: IconButton(
                              key: Key('messages-pending-remove-${a.id}'),
                              visualDensity: VisualDensity.compact,
                              tooltip: context.t('msg_attach_remove'),
                              onPressed: () => onRemovePending(a),
                              icon: const Icon(Icons.cancel, size: 18),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            if (filterError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Semantics(
                  liveRegion: true,
                  child: Text(filterError!, key: const Key('messages-blocked'), style: const TextStyle(color: TGColors.error, fontWeight: FontWeight.w700)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
              child: Row(
                children: [
                  IconButton(
                    key: const Key('messages-attach'),
                    tooltip: context.t('msg_attach'),
                    onPressed: pending.length >= MessagingLimits.maxAttachments ? null : onAttach,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                  ),
                  Expanded(
                    child: TextField(
                      key: const Key('messages-composer'),
                      controller: text,
                      minLines: 1,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: context.t('ui_message_hint'),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: TGColors.cta, width: 2),
                        ),
                      ),
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
        ],
      ),
    );
  }
}

final _none = TGChatMessage(id: '', senderId: '', receiverId: '', timestamp: DateTime(2000), ipAddress: '', body: '');

class _AttachmentThumb extends StatelessWidget {
  const _AttachmentThumb({required this.attachment, required this.size});
  final TGMessageAttachment attachment;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bytes = attachment.bytes;
    return Semantics(
      image: true,
      label: context.t('msg_photo_sem', {'name': attachment.fileName}),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: size,
          height: size * 0.75,
          child: bytes == null
              ? const ColoredBox(color: TGColors.border, child: Icon(Icons.photo_outlined))
              : Image.memory(bytes, fit: BoxFit.cover, excludeFromSemantics: true),
        ),
      ),
    );
  }
}

class _ContextPanel extends StatelessWidget {
  const _ContextPanel({
    required this.thread,
    required this.userId,
    required this.onMarkSold,
    required this.onArchive,
    required this.onReport,
    required this.onBlock,
  });

  final TGChatThread thread;
  final String userId;
  final VoidCallback onMarkSold;
  final VoidCallback onArchive;
  final VoidCallback onReport;
  final VoidCallback onBlock;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final svc = MessagingService.instance;
    final seller = userId == thread.sellerId;
    final phone = thread.otherPartyPhone(userId);
    final since = thread.otherPartySince(userId);
    final blocked = svc.hasBlocked(userId, thread.otherPartyId(userId));
    final archived = thread.isArchivedFor(userId);
    Widget action(Key key, IconData icon, String label, VoidCallback onTap, {Color? color}) => TGFocusRing(
          radius: 10,
          child: Material(
            type: MaterialType.transparency,
            child: ListTile(
              key: key,
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              leading: Icon(icon, size: 20, color: color),
              title: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
              onTap: onTap,
            ),
          ),
        );
    return Container(
      key: const Key('messages-context'),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(TGRadius.card),
        border: Border.all(color: theme.tertiary),
      ),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Semantics(header: true, child: Text(context.t('msg_ctx_listing'), style: theme.bodySmall.override(color: theme.secondaryText, fontWeight: FontWeight.w800))),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: thread.listingImageUrl.isEmpty
                  ? const ColoredBox(color: TGColors.border)
                  : WatermarkedImage(url: thread.listingImageUrl, surface: TGImageSurface.listingCard, fallback: (_) => const ColoredBox(color: TGColors.border)),
            ),
          ),
          const SizedBox(height: 8),
          Text(thread.listingTitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.bodyMedium.override(fontWeight: FontWeight.w800)),
          Text(
            [
              if (thread.listingPrice != null) formatPln(thread.listingPrice!),
              if (thread.listingCity.isNotEmpty) thread.listingCity,
              if (thread.listingNo != null) context.t('ui_listing_no_short', {'n': thread.listingNo!}),
            ].join(' · '),
            style: theme.bodySmall.override(color: theme.secondaryText),
          ),
          if (thread.soldToBuyer) ...[
            const SizedBox(height: 6),
            Text(context.t('msg_sold_to_buyer'), key: const Key('messages-sold-note'), style: theme.bodySmall.override(color: TGColors.cta, fontWeight: FontWeight.w800)),
          ],
          TextButton(
            key: const Key('messages-ctx-view-listing'),
            onPressed: () => context.go(thread.listingPath),
            child: Text(context.t('ui_view_listing')),
          ),
          Divider(color: theme.tertiary),
          Semantics(header: true, child: Text(context.t(seller ? 'msg_ctx_buyer' : 'msg_ctx_seller'), style: theme.bodySmall.override(color: theme.secondaryText, fontWeight: FontWeight.w800))),
          const SizedBox(height: 6),
          Text(thread.otherPartyName(userId), style: theme.bodyMedium.override(fontWeight: FontWeight.w800)),
          if (since != null)
            Text(
              context.t('msg_ctx_member_since', {'d': DateFormat('MMM y', Localizations.localeOf(context).languageCode).format(since)}),
              style: theme.bodySmall.override(color: theme.secondaryText),
            ),
          const SizedBox(height: 4),
          if (phone != null && phone.isNotEmpty)
            Row(
              children: [
                const Icon(Icons.call_outlined, size: 16),
                const SizedBox(width: 6),
                Expanded(child: SelectableText(phone, key: const Key('messages-ctx-phone'), style: theme.bodyMedium.override(fontWeight: FontWeight.w800))),
              ],
            )
          else
            Text(context.t('msg_ctx_no_phone'), style: theme.bodySmall.override(color: theme.secondaryText)),
          Divider(color: theme.tertiary),
          if (seller && !thread.soldToBuyer)
            action(const Key('messages-mark-sold'), Icons.sell_outlined, context.t('msg_mark_sold_to'), onMarkSold),
          action(const Key('messages-archive'), archived ? Icons.unarchive_outlined : Icons.archive_outlined, context.t(archived ? 'msg_unarchive' : 'msg_archive'), onArchive),
          action(const Key('messages-report-ctx'), Icons.flag_outlined, context.t('ui_report_conversation'), onReport),
          action(const Key('messages-block'), Icons.block, context.t(blocked ? 'msg_unblock' : 'msg_block'), onBlock, color: TGColors.error),
        ],
      ),
    );
  }
}
