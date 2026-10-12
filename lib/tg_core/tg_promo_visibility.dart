import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_services/promotion_service.dart';

/// Fires [onVisible] once the child is ≥50% on-screen for ≥1 second.
class TGPromoVisibility extends StatefulWidget {
  const TGPromoVisibility({
    super.key,
    required this.child,
    required this.onQualified,
  });

  final Widget child;
  final VoidCallback onQualified;

  @override
  State<TGPromoVisibility> createState() => _TGPromoVisibilityState();
}

class _TGPromoVisibilityState extends State<TGPromoVisibility> {
  Timer? _hold;
  bool _fired = false;

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }

  void _check() {
    if (_fired || !mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) {
      _hold?.cancel();
      _hold = null;
      return;
    }
    final size = box.size;
    if (size.isEmpty) return;
    final topLeft = box.localToGlobal(Offset.zero);
    final rect = topLeft & size;
    final view = Offset.zero & (MediaQuery.sizeOf(context));
    final overlap = rect.intersect(view);
    final visible = overlap.width > 0 && overlap.height > 0
        ? (overlap.width * overlap.height) / (size.width * size.height)
        : 0.0;
    if (visible >= 0.5) {
      _hold ??= Timer(const Duration(seconds: 1), () {
        if (!mounted || _fired) return;
        _fired = true;
        widget.onQualified();
      });
    } else {
      _hold?.cancel();
      _hold = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _check());
        return false;
      },
      child: LayoutBuilder(
        builder: (context, _) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _check());
          return widget.child;
        },
      ),
    );
  }
}

/// Whether promo stats should count for the current viewer (excludes owner / staff / bots).
bool tgShouldCountPromo({
  required FakeAuthState auth,
  required String ownerId,
}) {
  if (auth.role.isStaff) return false;
  if (auth.isLoggedIn && auth.userId == ownerId) return false;
  // Demo automation accounts — treat as bots.
  if (auth.userId.startsWith('bot_')) return false;
  return true;
}

void tgTrackPromoImpression({
  required BuildContext context,
  required String? promotionId,
  required String ownerId,
  bool isRepeat = false,
}) {
  if (promotionId == null || promotionId.isEmpty) return;
  final auth = context.read<FakeAuthState>();
  final count = tgShouldCountPromo(auth: auth, ownerId: ownerId);
  PromotionService.instance.recordImpression(promotionId, count: count);
  if (count) {
    TGAnalytics.track('promo_impression', {'promotionId': promotionId, 'ownerId': ownerId});
    if (isRepeat) {
      TGAnalytics.track('promo_repeat_shown', {'promotionId': promotionId});
    }
  }
}

void tgTrackPromoClick({
  required BuildContext context,
  required String? promotionId,
  required String ownerId,
}) {
  if (promotionId == null || promotionId.isEmpty) return;
  final auth = context.read<FakeAuthState>();
  final count = tgShouldCountPromo(auth: auth, ownerId: ownerId);
  PromotionService.instance.recordClick(promotionId, count: count);
  if (count) {
    TGAnalytics.track('promo_click', {'promotionId': promotionId, 'ownerId': ownerId});
  }
}
