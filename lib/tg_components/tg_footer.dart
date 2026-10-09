import 'package:flutter/material.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/products/products_query.dart';
import 'package:twoja_gastromania/tg_components/tg_map_card.dart';
import 'package:twoja_gastromania/tg_core/tg_company.dart';
import 'package:twoja_gastromania/tg_core/tg_contact.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';

/// Dark, full-bleed site footer.
///
/// * company contact info (address / phone / e-mail / hours – all actionable),
/// * B2B categories (deep links into `/products`),
/// * platform links (pricing, sellers, help, contact),
/// * a location map card with an "Open in Maps" button.
class TGFooter extends StatelessWidget {
  const TGFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final screenW = MediaQuery.sizeOf(context).width;
    final pad = screenW < 700 ? 16.0 : 24.0;

    final content = Padding(
      padding: EdgeInsets.fromLTRB(pad, 32, pad, 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, c) {
                  if (c.maxWidth >= 960) return const _WideColumns();
                  if (c.maxWidth >= 560) return const _MediumColumns();
                  return const _NarrowColumns();
                },
              ),
              const SizedBox(height: 24),
              Container(height: 1, color: theme.tertiary),
              const SizedBox(height: 16),
              const _BottomStrip(),
            ],
          ),
        ),
      ),
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        border: Border(top: BorderSide(color: theme.tertiary)),
      ),
      // ExpansionTile (phone accordions) needs a Material above it, otherwise
      // its ink is painted underneath this coloured container.
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(top: false, child: content),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Responsive arrangements
// ---------------------------------------------------------------------------

class _WideColumns extends StatelessWidget {
  const _WideColumns();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 14, child: _BrandAndContact()),
        SizedBox(width: 32),
        Expanded(flex: 12, child: _CategoriesColumn()),
        SizedBox(width: 32),
        Expanded(flex: 9, child: _PlatformColumn()),
        SizedBox(width: 32),
        Expanded(flex: 14, child: _LocationColumn()),
      ],
    );
  }
}

class _MediumColumns extends StatelessWidget {
  const _MediumColumns();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _BrandAndContact()),
            SizedBox(width: 28),
            Expanded(child: _LocationColumn()),
          ],
        ),
        SizedBox(height: 28),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _CategoriesColumn()),
            SizedBox(width: 28),
            Expanded(child: _PlatformColumn()),
          ],
        ),
      ],
    );
  }
}

class _NarrowColumns extends StatelessWidget {
  const _NarrowColumns();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _BrandAndContact(),
        const SizedBox(height: 12),
        _Accordion(title: context.t('ui_b2b_categories'), child: const _CategoryLinks()),
        _Accordion(title: context.t('ui_platform'), child: const _PlatformLinks()),
        const SizedBox(height: 12),
        const _LocationColumn(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Columns
// ---------------------------------------------------------------------------

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text, style: theme.titleSmall.override(fontSize: 14, letterSpacing: 0.2)),
    );
  }
}

class _BrandAndContact extends StatelessWidget {
  const _BrandAndContact();

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ClipOval(
              child: Image.asset(
                'assets/images/Hand_Shake_LOGO.png',
                width: 34,
                height: 34,
                cacheWidth: 102,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                TGCompany.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.titleMedium.override(fontSize: 17),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(TGCompany.tagline, style: theme.bodySmall.override(color: theme.secondaryText, lineHeight: 1.5)),
        const SizedBox(height: 14),
        _ContactLine(
          icon: Icons.place_outlined,
          text: TGCompany.fullAddress,
          tooltip: context.t('ui_open_in_maps'),
          onTap: () => openExternalUrl(context, TGCompany.mapsUri, failMessage: 'Could not open Maps'),
        ),
        _ContactLine(
          icon: Icons.call_outlined,
          text: TGCompany.phone,
          tooltip: 'Click to copy',
          onTap: () => copyPhoneNumber(context, TGCompany.phone),
        ),
        _ContactLine(
          icon: Icons.mail_outline,
          text: TGCompany.email,
          tooltip: 'Send an e-mail',
          onTap: () => openExternalUrl(context, TGCompany.emailUri, failMessage: 'Could not open your mail app'),
        ),
        const _ContactLine(icon: Icons.schedule_outlined, text: TGCompany.hours),
        if (TGCompany.social.values.any((u) => u != null)) ...[
          const SizedBox(height: 10),
          const _SocialRow(),
        ],
      ],
    );
  }
}

class _CategoriesColumn extends StatelessWidget {
  const _CategoriesColumn();

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_Heading(context.t('ui_b2b_categories')), const _CategoryLinks()],
      );
}

class _PlatformColumn extends StatelessWidget {
  const _PlatformColumn();

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_Heading(context.t('ui_platform')), const _PlatformLinks()],
      );
}

class _LocationColumn extends StatelessWidget {
  const _LocationColumn();

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Heading(context.t('ui_location')),
          TGMapCard(address: TGCompany.city, mapsUri: TGCompany.mapsUri),
        ],
      );
}

class _CategoryLinks extends StatelessWidget {
  const _CategoryLinks();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final c in TGCategory.values)
          _FooterLink(label: categoryLabel(c, t: (k) => context.t(k)), onTap: () => TGNav.category(context, c)),
        _FooterLink(label: context.t('ui_special_order'), onTap: () => TGNav.specialOrder(context)),
        _FooterLink(label: context.t('ui_restaurants'), onTap: () => TGNav.restaurantsForSale(context)),
      ],
    );
  }
}

class _PlatformLinks extends StatelessWidget {
  const _PlatformLinks();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FooterLink(label: context.t('ui_pricing'), onTap: () => TGNav.pricing(context)),
        _FooterLink(label: context.t('ui_for_sellers'), onTap: () => TGNav.addProduct(context)),
        _FooterLink(label: context.t('ui_verified_sellers'), onTap: () => TGNav.verifiedSellers(context)),
        _FooterLink(
          label: context.t('ui_help'),
          onTap: () => openExternalUrl(
            context,
            Uri(scheme: 'mailto', path: TGCompany.email, queryParameters: {'subject': 'Help'}),
            failMessage: 'Could not open your mail app',
          ),
        ),
        _FooterLink(
          label: context.t('ui_contact'),
          onTap: () => openExternalUrl(context, TGCompany.emailUri, failMessage: 'Could not open your mail app'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Atoms
// ---------------------------------------------------------------------------

class _FooterLink extends StatefulWidget {
  const _FooterLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_FooterLink> createState() => _FooterLinkState();
}

class _FooterLinkState extends State<_FooterLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Semantics(
      link: true,
      label: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: AnimatedDefaultTextStyle(
              duration: TGMotion.quick,
              style: theme.bodySmall.override(
                color: _hovered ? theme.primary : theme.secondaryText,
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              ),
              child: Text(widget.label),
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactLine extends StatefulWidget {
  const _ContactLine({required this.icon, required this.text, this.onTap, this.tooltip});

  final IconData icon;
  final String text;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  State<_ContactLine> createState() => _ContactLineState();
}

class _ContactLineState extends State<_ContactLine> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final tappable = widget.onTap != null;
    final color = tappable && _hovered ? theme.primary : theme.secondaryText;

    Widget line = Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(widget.icon, size: 17, color: tappable ? theme.primary : theme.secondaryText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.text,
              style: theme.bodySmall.override(color: color, fontWeight: FontWeight.w600, fontSize: 13.5, lineHeight: 1.3),
            ),
          ),
        ],
      ),
    );

    if (!tappable) return line;
    line = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onTap, child: line),
    );
    return Semantics(
      button: true,
      label: widget.text,
      child: widget.tooltip == null ? line : Tooltip(message: widget.tooltip!, child: line),
    );
  }
}

class _Accordion extends StatelessWidget {
  const _Accordion({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        expandedAlignment: Alignment.centerLeft,
        iconColor: theme.secondaryText,
        collapsedIconColor: theme.secondaryText,
        title: Text(title, style: theme.titleSmall.override(fontSize: 14)),
        children: [child],
      ),
    );
  }
}

class _SocialRow extends StatelessWidget {
  const _SocialRow();

  static const _icons = {
    'Facebook': Icons.facebook,
    'Instagram': Icons.camera_alt_outlined,
    'LinkedIn': Icons.work_outline,
    'YouTube': Icons.play_circle_outline,
  };

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Wrap(
      spacing: 10,
      children: [
        for (final e in TGCompany.social.entries)
          if (e.value != null)
            Tooltip(
              message: e.key,
              child: GestureDetector(
                onTap: () => openExternalUrl(context, Uri.parse(e.value!)),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: theme.alternate,
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.tertiary),
                  ),
                  child: Icon(_icons[e.key] ?? Icons.link, size: 18, color: theme.primaryText),
                ),
              ),
            ),
      ],
    );
  }
}

class _BottomStrip extends StatelessWidget {
  const _BottomStrip();

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final style = theme.bodySmall.override(color: theme.secondaryText);
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 6,
      spacing: 16,
      children: [
        Text('© ${DateTime.now().year} ${TGCompany.name}', style: style),
        Text(context.t('ui_legal_strip'), style: style),
      ],
    );
  }
}
