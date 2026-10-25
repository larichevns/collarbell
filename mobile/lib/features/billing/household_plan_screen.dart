import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../shared/error_messages.dart';
import '../../shared/widgets/cb_card.dart';
import '../../shared/widgets/cb_notice.dart';
import '../../shared/widgets/cb_section.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/collarbell_theme.dart';
import '../household/current_household.dart';
import '../household/household_labels.dart';
import 'billing_labels.dart';
import 'billing_repository.dart';
import 'household_plan.dart';

/// «Тариф»: the plan of the group on screen, this month's AI photos and when
/// they count from zero again, and what Premium gives. Nothing to buy: there
/// are no payments yet, and the stores allow no buttons or links to buy
/// elsewhere.
class HouseholdPlanScreen extends ConsumerWidget {
  const HouseholdPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final plan = ref.watch(householdPlanProvider);
    final value = plan.value;

    final List<Widget> content;
    if (value != null) {
      content = [_PlanCard(plan: value), ..._details(context, value)];
    } else if (plan.hasError && !plan.isLoading) {
      content = [
        CbErrorState(
          message: errorMessageFor(plan.error!, l10n),
          traceId: traceIdOf(plan.error!),
          onRetry: () => ref.invalidate(householdPlanProvider),
        ),
      ];
    } else {
      content = const [CbLoadingState()];
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.householdPlanTitle)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(householdPlanProvider);
          try {
            await ref.read(householdPlanProvider.future);
          } catch (error) {
            if (context.mounted) showRefreshFailed(context, error);
          }
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            CbSpace.s4,
            CbSpace.s4,
            CbSpace.s4,
            CbSpace.s12,
          ),
          children: content,
        ),
      ),
    );
  }

  List<Widget> _details(BuildContext context, HouseholdPlan plan) {
    final l10n = context.l10n;
    final text = context.cbText;
    final cb = context.cb;
    return [
      const SizedBox(height: CbSpace.s6),
      CbSection(
        title: l10n.householdPlanAiPhotos,
        child: _AiPhotos(plan: plan),
      ),
      if (!plan.premium) ...[
        const SizedBox(height: CbSpace.s6),
        CbSection(
          title: l10n.householdPlanPremiumTitle,
          child: CbCard(
            child: Row(
              children: [
                Icon(Symbols.workspace_premium_rounded, color: cb.primaryText),
                const SizedBox(width: CbSpace.s3),
                Expanded(
                  child: Text(
                    l10n.householdPlanPremiumAiPhotos(
                      plan.premiumAiPhotosPerMonth,
                    ),
                    style: text.body,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      const SizedBox(height: CbSpace.s6),
      CbNotice(message: l10n.householdPlanPaymentsNote),
    ];
  }
}

/// The plan's name, the group it belongs to, and until when it lasts.
class _PlanCard extends ConsumerWidget {
  const _PlanCard({required this.plan});

  final HouseholdPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = context.cbText;
    final cb = context.cb;
    final household = ref.watch(currentHouseholdProvider);
    final name = household?.name;
    final ends = planEnds(l10n, plan);
    return CbCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Symbols.workspace_premium_rounded,
            fill: plan.premium ? 1 : 0,
            color: plan.premium ? cb.primaryText : cb.inkMuted,
          ),
          const SizedBox(width: CbSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (name != null) ...[
                  Text(
                    l10n.householdPlanOf(
                      householdName(l10n, name, role: household?.role),
                    ),
                    style: text.bodySm.copyWith(color: cb.inkMuted),
                  ),
                  const SizedBox(height: CbSpace.s1),
                ],
                Text(planKindName(l10n, plan.kind), style: text.title),
                if (ends != null) ...[
                  const SizedBox(height: CbSpace.s1),
                  Text(ends, style: text.bodySm),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// This month's AI photos against the plan's limit, and when they count from
/// zero again.
class _AiPhotos extends StatelessWidget {
  const _AiPhotos({required this.plan});

  final HouseholdPlan plan;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.cbText;
    final cb = context.cb;
    final limit = plan.aiPhotosPerMonth;
    final usedUp = plan.aiPhotosUsedUp;
    return CbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.householdPlanAiPhotosUsed(plan.aiPhotosUsed, limit),
            style: text.numeral,
          ),
          const SizedBox(height: CbSpace.s3),
          // A level bar, rounded like the design system's (radius-full).
          ClipRRect(
            borderRadius: BorderRadius.circular(CbRadius.full),
            child: LinearProgressIndicator(
              value: limit <= 0 ? 1 : (plan.aiPhotosUsed / limit).clamp(0, 1),
              minHeight: CbSpace.s2,
              color: usedUp ? cb.danger : cb.primary,
              backgroundColor: cb.sunken,
              semanticsLabel: l10n.householdPlanAiPhotos,
              semanticsValue: l10n.householdPlanAiPhotosUsed(
                plan.aiPhotosUsed,
                limit,
              ),
            ),
          ),
          if (usedUp) ...[
            const SizedBox(height: CbSpace.s3),
            Text(l10n.householdPlanAiPhotosUsedUp, style: text.body),
          ],
          const SizedBox(height: CbSpace.s3),
          Text(l10n.householdPlanResetsOn(plan.resetsAt), style: text.bodySm),
          const SizedBox(height: CbSpace.s2),
          Text(
            l10n.householdPlanAiPhotosHelp,
            style: text.bodySm.copyWith(color: cb.inkMuted),
          ),
        ],
      ),
    );
  }
}
