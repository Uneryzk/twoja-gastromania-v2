import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/admin/listing_images_editor.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/seller/store_owner_edit.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_restaurant_listing.dart';
import 'package:twoja_gastromania/tg_models/tg_store_profile.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';
import 'package:twoja_gastromania/tg_services/restaurant_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';

/// Compact admin-only edit control used on public pages.
class AdminPageEditButton extends StatelessWidget {
  const AdminPageEditButton({
    super.key,
    required this.onPressed,
    this.labelKey = 'ui_admin_edit_page',
    this.compact = false,
  });

  final VoidCallback onPressed;
  final String labelKey;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<FakeAuthState>();
    if (!auth.isAdmin) return const SizedBox.shrink();
    if (compact) {
      return TextButton.icon(
        key: const Key('admin-page-edit'),
        onPressed: onPressed,
        icon: const Icon(Icons.edit_outlined, size: 16, color: TGColors.cta),
        label: Text(context.t(labelKey), style: const TextStyle(fontWeight: FontWeight.w800, color: TGColors.cta)),
      );
    }
    return TGButton(
      key: const Key('admin-page-edit'),
      onPressed: onPressed,
      label: context.t(labelKey),
      height: 36,
      variant: TGButtonVariant.outline,
      borderRadius: BorderRadius.circular(TGRadius.pill),
    );
  }
}

Future<void> showAdminStoreContentEdit(BuildContext context, TGStoreProfile profile) {
  return showStoreEditFlow(context, profile);
}

Future<void> showAdminRestaurantContentEdit(BuildContext context, RestaurantListing listing) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: _AdminListingContentSheet.restaurant(listing),
    ),
  );
}

Future<void> showAdminProductContentEdit(BuildContext context, TGProduct product) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: _AdminListingContentSheet.product(product),
    ),
  );
}

class _AdminListingContentSheet extends StatefulWidget {
  const _AdminListingContentSheet._({this.product, this.restaurant});
  factory _AdminListingContentSheet.product(TGProduct product) => _AdminListingContentSheet._(product: product);
  factory _AdminListingContentSheet.restaurant(RestaurantListing restaurant) =>
      _AdminListingContentSheet._(restaurant: restaurant);

  final TGProduct? product;
  final RestaurantListing? restaurant;

  @override
  State<_AdminListingContentSheet> createState() => _AdminListingContentSheetState();
}

class _AdminListingContentSheetState extends State<_AdminListingContentSheet> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _phone;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.restaurant?.title ?? widget.product?.title ?? '');
    _description = TextEditingController(text: widget.restaurant?.description ?? widget.product?.description ?? '');
    _phone = TextEditingController(text: widget.restaurant?.phone ?? widget.product?.phone ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final title = _title.text.trim();
    final description = _description.text.trim();
    final phone = _phone.text.trim();
    if (widget.restaurant != null) {
      RestaurantService.instance.replace(
        widget.restaurant!.copyWith(title: title, description: description, phone: phone.isEmpty ? widget.restaurant!.phone : phone),
      );
    }
    if (widget.product != null) {
      final next = widget.product!.copyWith(
        title: title,
        description: description,
        phone: phone.isEmpty ? widget.product!.phone : phone,
      );
      await TGProductService.instance.upsert(next);
      if (!mounted) return;
      final auth = context.read<FakeAuthState>();
      if (auth.ownedListings.any((e) => e.id == next.id)) {
        auth.upsertOwned(next);
      }
    }
    if (!mounted) return;
    setState(() => _saving = false);
    showTGToast(context, context.t('ui_admin_content_saved'));
    Navigator.pop(context);
  }

  Future<void> _openImages() async {
    await showListingImagesEditor(context, product: widget.product, restaurant: widget.restaurant);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openSeller() async {
    final ownerId = widget.restaurant?.ownerId ?? widget.product?.ownerKey;
    if (ownerId == null || ownerId.isEmpty) return;
    final profile = TGSellerProfileService.instance.bySellerKey(ownerId);
    if (profile == null) {
      showTGToast(context, context.t('ui_admin_seller_not_found'));
      return;
    }
    Navigator.pop(context);
    await context.push(profile.path);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.88,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(context.t('ui_admin_edit_listing'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              Text(context.t('ui_admin_edit_listing_sub'), style: theme.bodySmall.override(color: theme.secondaryText)),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    TextField(
                      key: const Key('admin-edit-title'),
                      controller: _title,
                      decoration: InputDecoration(labelText: context.t('ui_title')),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('admin-edit-description'),
                      controller: _description,
                      maxLines: 8,
                      decoration: InputDecoration(labelText: context.t('ui_description'), alignLabelWithHint: true),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('admin-edit-phone'),
                      controller: _phone,
                      decoration: InputDecoration(labelText: context.t('ui_phone')),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      key: const Key('admin-edit-images'),
                      onPressed: _openImages,
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: Text(context.t('ui_admin_edit_photos')),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const Key('admin-edit-seller-profile'),
                      onPressed: _openSeller,
                      icon: const Icon(Icons.storefront_outlined, size: 18),
                      label: Text(context.t('ui_admin_edit_seller_from_listing')),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TGButton(
                key: const Key('admin-edit-listing-save'),
                onPressed: _saving ? null : _save,
                label: _saving ? context.t('ui_saving') : context.t('ui_save'),
                height: 48,
                borderRadius: BorderRadius.circular(TGRadius.pill),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
