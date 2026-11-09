import 'package:flutter/material.dart';

import '../../../data/models/treat_refusal.dart';
import '../../../l10n/l10n.dart';

/// User-facing reason for a refused treat (brief 2026-11-09 §7), e.g.
/// "Daily treat limit reached (65/65). Resets at midnight."
String treatRefusalMessage(BuildContext context, TreatRefusal r) {
  final l = context.l10n;
  switch (r.code) {
    case TreatRefusal.capReached:
      final used = r.used, cap = r.cap;
      final counts = (used != null && cap != null) ? ' ($used/$cap)' : '';
      final resets = r.resetsAt;
      if (resets != null) {
        final t = MaterialLocalizations.of(context)
            .formatTimeOfDay(TimeOfDay.fromDateTime(resets));
        return l.treatRefusedCapReachedAt(counts, t);
      }
      return l.treatRefusedCapReached(counts);
    case TreatRefusal.rate:
      return l.treatRefusedRate;
    case TreatRefusal.windowClosed:
      return l.treatRefusedWindowClosed;
  }
  return l.treatRefusedGeneric(r.message ?? r.code);
}
