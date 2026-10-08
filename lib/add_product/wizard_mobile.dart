import 'package:flutter/material.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';

class WizardMobileHeader extends StatelessWidget {
  const WizardMobileHeader({
    super.key,
    required this.step,
    required this.labels,
    this.saving = false,
    this.saved = false,
    this.onSave,
  });

  final int step;
  final List<String> labels;
  final bool saving;
  final bool saved;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                context.t('ui_step_of', {'n': '${step + 1}', 'total': '${labels.length}', 'label': labels[step]}),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.titleSmall.override(fontWeight: FontWeight.w800),
              ),
            ),
            if (saving)
              Text(context.t('ui_saving'), style: theme.bodySmall.override(color: theme.secondaryText))
            else if (saved)
              Text(context.t('ui_saved_just_now'), style: theme.bodySmall.override(color: theme.secondaryText)),
            if (onSave != null)
              TextButton(key: const Key('wizard-save-draft'), onPressed: onSave, child: Text(context.t('ui_save'))),
          ],
        ),
      ),
    );
  }
}

class WizardProgressBar extends StatelessWidget {
  const WizardProgressBar({super.key, required this.step, required this.total});
  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: AnimatedContainer(
                duration: TGMotion.of(context, TGMotion.stepper),
                height: 4,
                decoration: BoxDecoration(
                  color: i <= step ? theme.primary : TGColors.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class WizardStickyBar extends StatelessWidget {
  const WizardStickyBar({
    super.key,
    required this.back,
    required this.next,
    this.totalLabel,
  });

  final Widget back;
  final Widget next;
  final String? totalLabel;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context).bottom;
    final kb = MediaQuery.viewInsetsOf(context).bottom;
    return Material(
      color: TGColors.surface,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + (kb > 0 ? kb : pad)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (totalLabel != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(totalLabel!, style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            Row(
              children: [
                Expanded(flex: 10, child: back),
                const SizedBox(width: 8),
                Expanded(flex: 16, child: next),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class WizardPreviewSheetChrome extends StatelessWidget {
  const WizardPreviewSheetChrome({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 48,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Semantics(
                    label: context.t('ui_drag_to_close'),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: TGColors.border, borderRadius: BorderRadius.circular(99)),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  key: const Key('wizard-preview-close'),
                  tooltip: context.t('ui_close'),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class WizardPreviewChip extends StatelessWidget {
  const WizardPreviewChip({super.key, required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: ActionChip(
          key: const Key('wizard-preview-chip'),
          avatar: const Icon(Icons.visibility_outlined, size: 18),
          label: Text(context.t('ui_preview')),
          onPressed: onOpen,
        ),
      ),
    );
  }
}

class WizardOfflineBanner extends StatelessWidget {
  const WizardOfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (!TGAnalytics.offline) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: TGColors.rating.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(context.t('ui_offline_draft'), style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class WizardStepSkeleton extends StatelessWidget {
  const WizardStepSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 5; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ShimmerBar(width: i.isEven ? double.infinity : 220, height: i == 0 ? 22 : 48),
          ),
      ],
    );
  }
}

class _ShimmerBar extends StatefulWidget {
  const _ShimmerBar({required this.width, required this.height});
  final double width;
  final double height;

  @override
  State<_ShimmerBar> createState() => _ShimmerBarState();
}

class _ShimmerBarState extends State<_ShimmerBar> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return Container(width: widget.width, height: widget.height, color: TGColors.surfaceHover);
    }
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 0.85).animate(_c),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(color: TGColors.surfaceHover, borderRadius: BorderRadius.circular(TGRadius.input)),
      ),
    );
  }
}
