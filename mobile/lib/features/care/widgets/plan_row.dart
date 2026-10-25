import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/collarbell_theme.dart';
import '../care.dart';
import '../care_labels.dart';
import 'done_button.dart';
import 'due_line.dart';
import 'kind_icon.dart';

/// One plan on the Health tab: the kind icon, the title, when it is due (in
/// the status colour), how often and when it was last done, and the round
/// "Done" button. Finished and paused plans show their status instead of a due
/// date and have no "Done".
class PlanRow extends StatelessWidget {
  const PlanRow({super.key, required this.plan, this.onTap, this.onDone});

  final CarePlan plan;

  /// Opens the plan's form.
  final VoidCallback? onTap;

  /// Opens the Done screen; null hides the button.
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cb = context.cb;
    final text = context.cbText;
    final onDone = this.onDone;
    final lastDone = plan.lastDoneOn;
    final facts = [
      planIntervalLabel(l10n, plan),
      if (lastDone != null)
        l10n.planLastDone(keepTogether(l10n.dateMedium(lastDone))),
    ];

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          CbSpace.s4,
          CbSpace.s3,
          CbSpace.s4,
          CbSpace.s3,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            KindIcon(kind: plan.kind),
            const SizedBox(width: CbSpace.s3),
            Expanded(
              // The texts are one node for screen readers; the button stays
              // its own.
              child: MergeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.title,
                      style: text.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: CbSpace.s1),
                    if (plan.status == CareStatus.inactive)
                      Text(
                        planStatusLabel(l10n, plan),
                        style: text.bodySm.copyWith(color: cb.inkMuted),
                      )
                    else
                      DueLine(
                        status: plan.status,
                        daysLeft: plan.daysLeft,
                        dueOn: plan.nextDueOn,
                      ),
                    Text(
                      facts.join(' · '),
                      style: text.bodySm.copyWith(color: cb.inkMuted),
                    ),
                  ],
                ),
              ),
            ),
            if (onDone != null) ...[
              const SizedBox(width: CbSpace.s2),
              DoneButton(onPressed: onDone),
            ],
          ],
        ),
      ),
    );
  }
}
