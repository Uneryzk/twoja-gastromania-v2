import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/admin_locale_state.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_deal_moderation.dart';
import 'package:twoja_gastromania/tg_models/tg_moderation.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_services/deal_moderation_service.dart';
import 'package:twoja_gastromania/tg_services/moderation_service.dart';

abstract final class TGAdminNav {
  static const queue = '/admin';
  static const listings = '/admin/listings';
  static const sellers = '/admin/sellers';
  static const audit = '/admin/audit';
  static const templates = '/admin/templates';
  static const deals = '/admin/deals';
  static String casePath(String listingNo) {
    if (listingNo.startsWith('s:')) return '/admin/s/${listingNo.substring(2)}';
    if (listingNo.startsWith('r:')) return '/admin/r/${listingNo.substring(2)}';
    return '/admin/l/$listingNo';
  }

  static String sellerCasePath(String sellerId) => '/admin/s/$sellerId';
  static String reviewCasePath(String reviewId) => '/admin/r/$reviewId';
  static String dealCasePath(String dealNo) => '/admin/d/$dealNo';
  static String dealsQueuePath(TGDealQueueKind kind) =>
      kind == TGDealQueueKind.objection ? deals : '$deals?queue=${kind.name}';

  static void queuePage(BuildContext context, {String? filter}) =>
      context.go(filter == null ? queue : '$queue?filter=$filter');

  static void dealsQueue(BuildContext context, [TGDealQueueKind kind = TGDealQueueKind.objection]) =>
      context.go(dealsQueuePath(kind));

  static void openCase(BuildContext context, String listingNo) {
    ModerationService.instance.openCaseTracked(listingNo);
    context.go(casePath(listingNo));
  }

  static void openDeal(BuildContext context, String dealNo) {
    DealModerationService.instance.openTracked(dealNo);
    context.go(dealCasePath(dealNo));
  }
}

class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.child, this.section = 'queue'});

  final Widget child;
  final String section;

  static const routeName = 'Admin';
  static const routePath = '/admin';

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  @override
  void initState() {
    super.initState();
    ModerationService.instance.ensureSeeded();
    DealModerationService.instance.ensureSeeded();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AdminLocaleState>();
    context.watch<DealModerationService>();
    return AdminL10nScope(
      child: Builder(builder: (context) => _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    final auth = context.watch<FakeAuthState>();
    final mod = context.watch<ModerationService>();
    if (!auth.canModerate) return const AdminForbiddenPage();
    if (widget.section == 'templates' && !auth.isAdmin) return const AdminForbiddenPage();

    final w = MediaQuery.sizeOf(context).width;
    final showSidebar = w >= TGBreakpoints.desktop;
    final phone = w < TGBreakpoints.phone;

    return Scaffold(
      backgroundColor: TGColors.background,
      body: Column(
        children: [
          AdminTopBar(role: auth.role),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showSidebar) AdminSideMenu(section: widget.section, mod: mod, isAdmin: auth.isAdmin),
                Expanded(child: widget.child),
              ],
            ),
          ),
          if (!showSidebar && !phone) _MobileAdminTabs(section: widget.section, isAdmin: auth.isAdmin),
        ],
      ),
    );
  }
}

class AdminTopBar extends StatefulWidget {
  const AdminTopBar({super.key, required this.role});
  final TGUserRole role;

  @override
  State<AdminTopBar> createState() => _AdminTopBarState();
}

class _AdminTopBarState extends State<AdminTopBar> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _go(String raw) {
    final dealNo = DealModerationService.instance.resolveSearch(raw);
    if (dealNo != null) {
      TGAdminNav.openDeal(context, dealNo);
      return;
    }
    final listingNo = ModerationService.instance.resolveSearch(raw);
    if (listingNo == null) return;
    TGAdminNav.openCase(context, listingNo);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
    return Material(
      color: TGColors.adminBar,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: narrow ? 8 : 16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => TGAdminNav.queuePage(context),
                  child: Row(
                    children: [
                      ClipOval(
                        child: Image.asset('assets/images/Hand_Shake_LOGO.png', width: 28, height: 28, fit: BoxFit.cover),
                      ),
                      if (!narrow) ...[
                        const SizedBox(width: 10),
                        Text('Twoja Gastromania', style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: narrow ? 8 : 16),
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      key: const Key('admin-search'),
                      controller: _search,
                      style: theme.bodyMedium,
                      textInputAction: TextInputAction.go,
                      onSubmitted: _go,
                      decoration: InputDecoration(
                        hintText: narrow ? context.t('ui_listing_no_header') : context.t('ui_admin_search'),
                        isDense: true,
                        prefixIcon: const Icon(Icons.search, size: 18, color: TGColors.textSecondary),
                        filled: true,
                        fillColor: TGColors.surface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(TGRadius.input),
                          borderSide: const BorderSide(color: TGColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(TGRadius.input),
                          borderSide: const BorderSide(color: TGColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(TGRadius.input),
                          borderSide: const BorderSide(color: TGColors.cta, width: 1.4),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const AdminLangSwitcher(),
                if (!narrow) ...[
                  const SizedBox(width: 8),
                  _RoleBadge(role: widget.role),
                ],
                IconButton(
                  tooltip: context.t('ui_exit'),
                  onPressed: () => TGNav.home(context),
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final TGUserRole role;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('admin-role-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: TGColors.cta.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(TGRadius.pill),
        border: Border.all(color: TGColors.cta.withValues(alpha: 0.5)),
      ),
      child: Text(adminRoleLabel(context, role), style: const TextStyle(color: TGColors.cta, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }
}

class AdminSideMenu extends StatelessWidget {
  const AdminSideMenu({super.key, required this.section, required this.mod, required this.isAdmin});
  final String section;
  final ModerationService mod;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      width: 220,
      color: TGColors.adminBar,
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _NavTile(
            selected: section == 'queue',
            icon: Icons.inbox_outlined,
            label: context.t('ui_admin_queue'),
            subtitle: context.t('ui_queue_counts', {
              'n': '${mod.newCount}',
              'r': '${mod.inReviewCount}',
              'w': '${mod.waitingCount}',
              'a': '${mod.openAppealCount}',
            }),
            onTap: () => TGAdminNav.queuePage(context),
          ),
          _NavTile(selected: section == 'listings', icon: Icons.search, label: context.t('ui_admin_listings'), onTap: () => context.go(TGAdminNav.listings)),
          _NavTile(selected: section == 'sellers', icon: Icons.storefront_outlined, label: context.t('ui_admin_sellers'), onTap: () => context.go(TGAdminNav.sellers)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
            child: Text(context.t('ui_admin_deals'), style: theme.labelSmall.override(color: theme.secondaryText, fontWeight: FontWeight.w900, fontSize: 10)),
          ),
          _DealsNavGroup(section: section),
          const SizedBox(height: 8),
          _NavTile(selected: section == 'audit', icon: Icons.receipt_long_outlined, label: context.t('ui_admin_audit'), onTap: () => context.go(TGAdminNav.audit)),
          if (isAdmin)
            _NavTile(selected: section == 'templates', icon: Icons.email_outlined, label: context.t('ui_admin_templates'), onTap: () => context.go(TGAdminNav.templates)),
          const Spacer(),
          Text(context.t('ui_platform_principles'), style: theme.labelSmall.override(color: theme.secondaryText, fontSize: 10, lineHeight: 1.35)),
        ],
      ),
    );
  }
}

class _DealsNavGroup extends StatelessWidget {
  const _DealsNavGroup({required this.section});
  final String section;

  @override
  Widget build(BuildContext context) {
    final deals = context.watch<DealModerationService>();
    final uri = GoRouterState.of(context).uri;
    final onDeals = section == 'deals' || uri.path.startsWith('/admin/deals') || uri.path.startsWith('/admin/d/');
    final queue = uri.queryParameters['queue'] ?? (uri.path == '/admin/deals' ? 'objection' : '');
    Widget item(TGDealQueueKind kind, String key) {
      final n = deals.count(kind);
      final selected = onDeals && ((kind == TGDealQueueKind.objection && (queue.isEmpty || queue == 'objection') && !uri.path.startsWith('/admin/d/')) || queue == kind.name);
      return _NavTile(
        selected: selected,
        icon: switch (kind) {
          TGDealQueueKind.objection => Icons.gavel_outlined,
          TGDealQueueKind.flagged => Icons.flag_outlined,
          TGDealQueueKind.dispute => Icons.report_outlined,
          TGDealQueueKind.appeal => Icons.replay_outlined,
          TGDealQueueKind.all => Icons.list_alt_outlined,
        },
        label: '${context.t(key)}${kind == TGDealQueueKind.all ? '' : ' ($n)'}',
        onTap: () => TGAdminNav.dealsQueue(context, kind),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        item(TGDealQueueKind.objection, 'ui_admin_objections'),
        item(TGDealQueueKind.flagged, 'ui_admin_flagged_reviews'),
        item(TGDealQueueKind.dispute, 'ui_admin_disputes'),
        item(TGDealQueueKind.appeal, 'ui_admin_deal_appeals'),
        item(TGDealQueueKind.all, 'ui_admin_all_deals'),
      ],
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.selected, required this.icon, required this.label, required this.onTap, this.subtitle});
  final bool selected;
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? TGColors.surfaceHover : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: selected ? TGColors.cta : TGColors.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: selected ? TGColors.textPrimary : TGColors.textSecondary))),
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: const TextStyle(color: TGColors.textSecondary, fontSize: 10, height: 1.3)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileAdminTabs extends StatelessWidget {
  const _MobileAdminTabs({required this.section, required this.isAdmin});
  final String section;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TGColors.adminBar,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              _tab(context, 'queue', Icons.inbox_outlined, TGAdminNav.queue),
              _tab(context, 'listings', Icons.search, TGAdminNav.listings),
              _tab(context, 'sellers', Icons.storefront_outlined, TGAdminNav.sellers),
              _tab(context, 'deals', Icons.handshake_outlined, TGAdminNav.deals),
              _tab(context, 'audit', Icons.receipt_long_outlined, TGAdminNav.audit),
              if (isAdmin) _tab(context, 'templates', Icons.email_outlined, TGAdminNav.templates),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(BuildContext context, String id, IconData icon, String path) {
    final on = section == id || (id == 'deals' && section.startsWith('deals'));
    return Expanded(
      child: InkWell(
        onTap: () => context.go(path),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: on ? TGColors.cta : TGColors.textSecondary),
            const SizedBox(height: 2),
            Container(width: 12, height: 2, color: on ? TGColors.cta : Colors.transparent),
          ],
        ),
      ),
    );
  }
}

class AdminForbiddenPage extends StatelessWidget {
  const AdminForbiddenPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final auth = context.watch<FakeAuthState>();
    return Scaffold(
      key: const Key('admin-403'),
      backgroundColor: TGColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 40, color: TGColors.error),
                const SizedBox(height: 12),
                Text(context.t('ui_admin_forbidden'), style: theme.titleLarge.override(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(context.t('ui_admin_403'), textAlign: TextAlign.center, style: theme.bodyMedium.override(color: theme.secondaryText)),
                const SizedBox(height: 18),
                TGButton(onPressed: () => TGNav.home(context), label: context.t('ui_home'), height: 44),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final r in TGUserRole.values)
                      ChoiceChip(
                        label: Text(adminRoleLabel(context, r)),
                        selected: auth.role == r,
                        onSelected: (_) => auth.setRole(r),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AdminSlaChip extends StatelessWidget {
  const AdminSlaChip({super.key, required this.row, this.now});
  final TGQueueCase row;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final t = now ?? DateTime.now();
    final tone = row.slaTone(t);
    final color = switch (tone) {
      TGSlaTone.ok => TGColors.textSecondary,
      TGSlaTone.warning => TGColors.slaAmber,
      TGSlaTone.overdue => TGColors.error,
    };
    final age = row.age(t);
    final overdue = t.isAfter(row.slaDeadline);
    String label;
    if (overdue) {
      final late = t.difference(row.slaDeadline);
      label = context.t('ui_sla_overdue', {'n': _fmt(late)});
    } else {
      label = _fmt(age);
    }
    return AnimatedContainer(
      duration: tgAnim(context, const Duration(milliseconds: 280)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(TGRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11)),
    );
  }

  static String _fmt(Duration d) {
    if (d.inHours < 1) return '${d.inMinutes}m';
    if (d.inHours < 48) return '${d.inHours}h';
    return '${d.inDays}d';
  }
}

class AdminDeadlineChip extends StatelessWidget {
  const AdminDeadlineChip({super.key, required this.label, required this.tone});
  final String label;
  final TGSlaTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      TGSlaTone.ok => TGColors.textSecondary,
      TGSlaTone.warning => TGColors.slaAmber,
      TGSlaTone.overdue => TGColors.error,
    };
    return AnimatedContainer(
      duration: tgAnim(context, const Duration(milliseconds: 280)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(TGRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11)),
    );
  }
}

class AdminStatusChip extends StatelessWidget {
  const AdminStatusChip({super.key, required this.status});
  final TGReportStatus status;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: tgAnim(context, const Duration(milliseconds: 200)),
      child: Container(
        key: ValueKey(status),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: TGColors.surfaceHover,
          borderRadius: BorderRadius.circular(TGRadius.pill),
          border: Border.all(color: TGColors.border),
        ),
        child: Text(adminStatusLabel(context, status), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class AdminReasonChip extends StatelessWidget {
  const AdminReasonChip({super.key, required this.reason});
  final TGReportReason reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: TGColors.surfaceHover,
        borderRadius: BorderRadius.circular(TGRadius.pill),
        border: Border.all(color: TGColors.border),
      ),
      child: Text(adminReasonLabel(context, reason), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class AdminCard extends StatelessWidget {
  const AdminCard({super.key, required this.child, this.padding = const EdgeInsets.all(14)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TGColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: TGColors.border),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

Future<T?> showAdminDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black54,
    transitionDuration: tgAnim(context, const Duration(milliseconds: 200)),
    pageBuilder: (ctx, _, __) => AdminL10nScope(child: Builder(builder: builder)),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(curved), child: child),
      );
    },
  );
}

class AdminDialogScaffold extends StatelessWidget {
  const AdminDialogScaffold({super.key, required this.title, required this.child, this.actions, this.width = 520});
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Shortcuts(
      shortcuts: {LogicalKeySet(LogicalKeyboardKey.escape): const DismissIntent()},
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(onInvoke: (_) {
            Navigator.of(context).maybePop();
            return null;
          }),
        },
        child: Focus(
          autofocus: true,
          child: Center(
            child: Material(
              color: TGColors.surface,
              borderRadius: BorderRadius.circular(TGRadius.modal),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: width, maxHeight: MediaQuery.sizeOf(context).height * 0.86),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(title, style: theme.titleMedium.override(fontWeight: FontWeight.w900))),
                          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, size: 18)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Flexible(child: SingleChildScrollView(child: child)),
                      if (actions != null) ...[
                        const SizedBox(height: 16),
                        Row(mainAxisAlignment: MainAxisAlignment.end, children: actions!),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class EmailPreviewBlock extends StatelessWidget {
  const EmailPreviewBlock({super.key, required this.email});
  final TGQueuedEmail email;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t('ui_email_preview'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: TGColors.cta)),
          const SizedBox(height: 6),
          Text(context.t('ui_email_to', {'to': email.to}), style: const TextStyle(fontSize: 12, color: TGColors.textSecondary)),
          Text(email.subject, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 6),
          Text(email.body, style: const TextStyle(fontSize: 12, height: 1.4)),
        ],
      ),
    );
  }
}

String adminSellerKindL10n(BuildContext context, TGSellerType type, {required bool verified}) {
  if (verified) return context.t('ui_seller_verified');
  return type == TGSellerType.store ? context.t('ui_seller_store') : context.t('ui_seller_private');
}

String adminRoleLabel(BuildContext context, TGUserRole role) => switch (role) {
      TGUserRole.visitor => context.t('ui_role_visitor'),
      TGUserRole.seller => context.t('ui_role_seller'),
      TGUserRole.storeSeller => context.t('ui_role_store_seller'),
      TGUserRole.moderator => context.t('ui_role_moderator'),
      TGUserRole.admin => context.t('ui_role_admin'),
      TGUserRole.buyer => context.t('ui_role_buyer'),
    };

String adminReasonLabel(BuildContext context, TGReportReason reason) => context.t('ui_reason_${reason.name}');

String adminStatusLabel(BuildContext context, TGReportStatus status) => switch (status) {
      TGReportStatus.new_ => context.t('ui_status_new'),
      TGReportStatus.inReview => context.t('ui_status_in_review'),
      TGReportStatus.waitingSeller => context.t('ui_status_waiting_seller'),
      TGReportStatus.resolvedRemoved => context.t('ui_status_resolved_removed'),
      TGReportStatus.resolvedNoViolation => context.t('ui_status_no_violation'),
      TGReportStatus.resolvedOther => context.t('ui_status_resolved'),
    };

String adminPriorityLabel(BuildContext context, TGModerationPriority priority) => switch (priority) {
      TGModerationPriority.high => context.t('ui_priority_high'),
      TGModerationPriority.medium => context.t('ui_priority_medium'),
      TGModerationPriority.low => context.t('ui_priority_low'),
    };

class AdminLangSwitcher extends StatelessWidget {
  const AdminLangSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final current = context.watch<AdminLocaleState>().languageCode;
    return Container(
      key: const Key('admin-lang-switcher'),
      height: 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TGRadius.pill),
        border: Border.all(color: TGColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final code in AdminLocaleState.supported)
            InkWell(
              key: Key('admin-lang-$code'),
              onTap: () => context.read<AdminLocaleState>().setLanguage(code),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: current == code ? TGColors.cta.withValues(alpha: 0.18) : Colors.transparent,
                  borderRadius: BorderRadius.circular(TGRadius.pill),
                ),
                child: Text(
                  code.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: current == code ? TGColors.cta : TGColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AdminPrinciplesFooter extends StatelessWidget {
  const AdminPrinciplesFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Text(context.t('ui_platform_principles'), style: const TextStyle(color: TGColors.textSecondary, fontSize: 11, height: 1.35)),
    );
  }
}
