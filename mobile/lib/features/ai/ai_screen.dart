import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/l10n.dart';
import '../../shared/error_messages.dart';
import '../../shared/widgets/cb_card.dart';
import '../../shared/widgets/cb_notice.dart';
import '../../shared/widgets/cb_section.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/collarbell_theme.dart';
import '../billing/open_plan_button.dart';
import '../care/care_labels.dart';
import '../household/current_household.dart';
import 'ai.dart';
import 'ai_labels.dart';
import 'ai_repository.dart';

/// The AI connection (More → AI): whether the server reads photos with AI
/// (it is set up in the server's configuration, not in the app), its
/// models, the free-tier warning, this month's use, and a connection test.
class AiScreen extends ConsumerStatefulWidget {
  const AiScreen({super.key});

  @override
  ConsumerState<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends ConsumerState<AiScreen> {
  var _testing = false;
  AiTestResult? _test;
  Object? _testError;

  @override
  void initState() {
    super.initState();
    // The status is kept for the session; this screen shows it fresh (and
    // so refreshes the scan buttons too).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.invalidate(aiStatusProvider);
    });
  }

  Future<void> _testConnection() async {
    if (_testing) return;
    final ai = ref.read(aiRepositoryProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() {
      _testing = true;
      _test = null;
      _testError = null;
    });
    try {
      final test = await ai.testConnection();
      if (mounted) setState(() => _test = test);
    } catch (error) {
      debugPrint('Testing the AI connection failed: $error');
      if (mounted) setState(() => _testError = error);
    } finally {
      // The test is a request too: this month's numbers change.
      container.invalidate(aiStatusProvider);
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = ref.watch(aiStatusProvider);
    final value = status.value;

    final List<Widget> content;
    if (value != null) {
      content = [
        _StatusCard(status: value),
        if (value.freeTier) ...[
          const SizedBox(height: CbSpace.s3),
          CbNotice.warning(message: l10n.aiFreeTierWarning),
        ],
        if (value.models.isNotEmpty) ...[
          const SizedBox(height: CbSpace.s6),
          CbSection(
            title: l10n.aiModelsTitle,
            child: _Models(models: value.models),
          ),
        ],
        const SizedBox(height: CbSpace.s6),
        CbSection(
          title: l10n.aiUsageTitle,
          child: _Usage(usage: value.thisMonth),
        ),
        // The test is a request helpers can't make.
        if (ref.watch(householdPermissionsProvider).canEdit) ...[
          const SizedBox(height: CbSpace.s6),
          CbSection(
            title: l10n.aiTestTitle,
            child: _Test(
              testing: _testing,
              result: _test,
              error: _testError,
              onTest: _testConnection,
            ),
          ),
        ],
      ];
    } else if (status.hasError) {
      content = [
        CbErrorState(
          message: errorMessageFor(status.error!, l10n),
          traceId: traceIdOf(status.error!),
          onRetry: () => ref.invalidate(aiStatusProvider),
        ),
      ];
    } else {
      content = const [CbLoadingState()];
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aiTitle)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(aiStatusProvider);
          try {
            await ref.read(aiStatusProvider.future);
          } catch (_) {
            // The error is shown by the error state.
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
}

/// Connected or not, and what that means.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});

  final AiStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cb = context.cb;
    final text = context.cbText;
    final configured = status.configured;
    return CbCard(
      child: MergeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              configured ? Symbols.check_circle_rounded : Symbols.info_rounded,
              color: configured ? cb.primaryText : cb.inkMuted,
            ),
            const SizedBox(width: CbSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    configured ? l10n.aiConnected : l10n.aiNotConnected,
                    style: text.subtitle,
                  ),
                  const SizedBox(height: CbSpace.s1),
                  Text(
                    configured ? l10n.aiConnectedBody : l10n.aiNotConnectedBody,
                    style: text.bodySm.copyWith(color: cb.inkMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The chain of models, in the order they are tried.
class _Models extends StatelessWidget {
  const _Models({required this.models});

  final List<AiModel> models;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cb = context.cb;
    final text = context.cbText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CbCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < models.length; i++) ...[
                if (i > 0) const Divider(indent: CbSpace.s4),
                MergeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CbSpace.s4,
                      vertical: CbSpace.s3,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(models[i].name, style: text.code),
                              Text(
                                aiProviderLabel(l10n, models[i].provider),
                                style: text.bodySm.copyWith(color: cb.inkMuted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: CbSpace.s2),
                        // Not colour alone: an icon and words.
                        Icon(
                          models[i].ready
                              ? Symbols.check_circle_rounded
                              : Symbols.key_off_rounded,
                          size: 18,
                          color: models[i].ready ? cb.primaryText : cb.inkMuted,
                        ),
                        const SizedBox(width: CbSpace.s1),
                        Text(
                          models[i].ready
                              ? l10n.aiModelReady
                              : l10n.aiModelNotReady,
                          style: text.bodySm.copyWith(
                            color: models[i].ready
                                ? cb.primaryText
                                : cb.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: CbSpace.s2),
        Text(
          l10n.aiModelsHint,
          style: text.bodySm.copyWith(color: cb.inkMuted),
        ),
      ],
    );
  }
}

/// This month's requests and tokens.
class _Usage extends StatelessWidget {
  const _Usage({required this.usage});

  final AiUsage usage;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final numbers = NumberFormat.decimalPattern(l10n.localeName);
    return CbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (label, value) in [
            (l10n.aiUsageRequests, usage.requests),
            (l10n.aiUsageInputTokens, usage.inputTokens),
            (l10n.aiUsageOutputTokens, usage.outputTokens),
          ])
            CbDetailRow(label: label, value: numbers.format(value)),
        ],
      ),
    );
  }
}

/// "Test connection" and its answer: the model and how fast it answered,
/// or what went wrong.
class _Test extends StatelessWidget {
  const _Test({
    required this.testing,
    required this.result,
    required this.error,
    required this.onTest,
  });

  final bool testing;
  final AiTestResult? result;
  final Object? error;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cb = context.cb;
    final text = context.cbText;
    final result = this.result;
    final error = this.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.aiTestHint, style: text.body),
        const SizedBox(height: CbSpace.s3),
        OutlinedButton.icon(
          onPressed: testing ? null : onTest,
          icon: testing
              ? const SizedBox.square(
                  dimension: CbSpace.s5,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Symbols.wifi_tethering_rounded),
          label: Text(l10n.aiTestButton),
        ),
        if (result != null && result.ok) ...[
          const SizedBox(height: CbSpace.s3),
          Semantics(
            liveRegion: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Symbols.check_circle_rounded, color: cb.primaryText),
                const SizedBox(width: CbSpace.s2),
                Expanded(
                  child: Text(
                    l10n.aiTestOk(
                      result.model ?? '',
                      formatDecimal(
                        l10n,
                        (result.latency.inMilliseconds / 100).round() / 10,
                      ),
                    ),
                    style: text.body,
                  ),
                ),
              ],
            ),
          ),
        ] else if (error != null && isAiLimit(error)) ...[
          // The connection may well work: it's the month's photos.
          const SizedBox(height: CbSpace.s3),
          CbNotice.error(message: errorMessageFor(error, l10n)),
          const Align(
            alignment: AlignmentDirectional.centerStart,
            child: OpenPlanButton(),
          ),
        ] else if (result != null || error != null) ...[
          const SizedBox(height: CbSpace.s3),
          CbNotice.error(
            message: [
              l10n.aiTestFailed,
              if (result != null)
                aiTestProblemLabel(l10n, result.problem)
              else
                errorMessageFor(error!, l10n),
            ].join(' '),
          ),
        ],
      ],
    );
  }
}
