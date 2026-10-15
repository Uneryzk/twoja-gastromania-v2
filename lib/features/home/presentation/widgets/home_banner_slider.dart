import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/admin/admin_chrome.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_home_banner.dart';
import 'package:twoja_gastromania/tg_services/home_banner_service.dart';

/// Floating staff control on a home-hero slide. Hidden for visitors and sellers.
class HomeBannerEditButton extends StatelessWidget {
  const HomeBannerEditButton({super.key, required this.banner, required this.onPressed});

  final TGHomeBanner banner;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<FakeAuthState>();
    if (!auth.canModerate) return const SizedBox.shrink();
    final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
    return Semantics(
      button: true,
      label: context.t('ui_banner_edit_sem'),
      child: Material(
        color: Colors.black.withValues(alpha: 0.78),
        elevation: 4,
        borderRadius: BorderRadius.circular(TGRadius.input),
        child: InkWell(
          key: Key('home-banner-edit-${banner.id}'),
          onTap: onPressed,
          borderRadius: BorderRadius.circular(TGRadius.input),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: phone ? 10 : 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.edit_outlined, size: 16, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  context.t('ui_banner_edit'),
                  style: GoogleFonts.interTight(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.40,
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

/// Staff modal: title, subtitle, image path, CTA label, target URL → [HomeBannerService].
Future<void> showHomeBannerEditDialog(BuildContext context, {required TGHomeBanner banner}) {
  final title = banner.hasTitleOverride ? banner.title : context.t(banner.titleKey);
  final subtitle = banner.hasSubtitleOverride ? banner.subtitle : context.t(banner.subtitleKey);
  final button = banner.hasButtonOverride ? banner.buttonText : context.t('ui_read_more');
  return showAdminDialog<void>(
    context: context,
    builder: (ctx) => _HomeBannerEditDialog(
      banner: banner,
      initialTitle: title,
      initialSubtitle: subtitle,
      initialButton: button,
    ),
  );
}

class _HomeBannerEditDialog extends StatefulWidget {
  const _HomeBannerEditDialog({
    required this.banner,
    required this.initialTitle,
    required this.initialSubtitle,
    required this.initialButton,
  });

  final TGHomeBanner banner;
  final String initialTitle;
  final String initialSubtitle;
  final String initialButton;

  @override
  State<_HomeBannerEditDialog> createState() => _HomeBannerEditDialogState();
}

class _HomeBannerEditDialogState extends State<_HomeBannerEditDialog> {
  late final TextEditingController _title;
  late final TextEditingController _subtitle;
  late final TextEditingController _image;
  late final TextEditingController _button;
  late final TextEditingController _target;
  String? _error;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initialTitle);
    _subtitle = TextEditingController(text: widget.initialSubtitle);
    _image = TextEditingController(text: widget.banner.imageUrl);
    _button = TextEditingController(text: widget.initialButton);
    _target = TextEditingController(text: widget.banner.targetUrl);
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _image.dispose();
    _button.dispose();
    _target.dispose();
    super.dispose();
  }

  void _save() {
    final auth = context.read<FakeAuthState>();
    final err = HomeBannerService.instance.save(
      actor: auth,
      banner: widget.banner.copyWith(
        title: _title.text,
        subtitle: _subtitle.text,
        imageUrl: _image.text,
        buttonText: _button.text,
        targetUrl: _target.text,
      ),
    );
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    showTGToast(context, context.t('ui_admin_content_saved'));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AdminDialogScaffold(
      title: context.t('ui_banner_edit_dialog'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.t('ui_cancel'))),
        const SizedBox(width: 8),
        TGButton(
          key: const Key('home-banner-edit-save'),
          onPressed: _save,
          label: context.t('ui_save'),
          height: 40,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('home-banner-edit-title'),
            controller: _title,
            decoration: InputDecoration(labelText: context.t('ui_title')),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('home-banner-edit-subtitle'),
            controller: _subtitle,
            maxLines: 3,
            decoration: InputDecoration(labelText: context.t('ui_banner_subtitle'), alignLabelWithHint: true),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('home-banner-edit-image'),
            controller: _image,
            decoration: InputDecoration(labelText: context.t('ui_banner_image')),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('home-banner-edit-button'),
            controller: _button,
            decoration: InputDecoration(labelText: context.t('ui_banner_cta')),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('home-banner-edit-target'),
            controller: _target,
            decoration: InputDecoration(labelText: context.t('ui_banner_target')),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(context.t(_error!), style: TextStyle(color: FlutterFlowTheme.of(context).error, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}
