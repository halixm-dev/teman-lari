import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/activity.dart';
import '../../../domain/entities/rehab_feedback.dart';
import '../../../domain/entities/rehab_program.dart';
import '../../providers/rehab_provider.dart';
import 'rehab_check_in_fields.dart';
import 'rehab_historical_time.dart';
export 'rehab_check_in_fields.dart' show CheckInWindow;

Future<void> showRehabCheckIn(
  BuildContext context, {
  required Activity activity,
  required RehabProgram program,
  RehabFeedback? existing,
  CheckInWindow window = CheckInWindow.postRun,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => RehabCheckInSheet(
    activity: activity,
    program: program,
    existing: existing,
    window: window,
  ),
);

class RehabCheckInSheet extends ConsumerStatefulWidget {
  final Activity activity;
  final RehabProgram program;
  final RehabFeedback? existing;
  final CheckInWindow window;
  const RehabCheckInSheet({
    super.key,
    required this.activity,
    required this.program,
    this.existing,
    this.window = CheckInWindow.postRun,
  });
  @override
  ConsumerState<RehabCheckInSheet> createState() => _RehabCheckInSheetState();
}

class _RehabCheckInSheetState extends ConsumerState<RehabCheckInSheet> {
  DateTime? _historicalTime;
  double? _pain;
  bool? _sharp;
  bool? _stiff;
  bool? _baseline;
  AsyncValue<void> _save = const AsyncData(null);
  bool get _morning => widget.window == CheckInWindow.morningAfter;
  bool get _needsHistoricTime =>
      !_morning &&
      widget.existing?.postRunPain == null &&
      widget.existing?.morningAfterRecordedAt != null;
  bool get _complete =>
      (!_needsHistoricTime || _historicalTime != null) &&
      _pain != null &&
      (_morning ? _stiff != null && _baseline != null : _sharp != null);

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _pain = _morning ? existing?.morningAfterPain : existing?.postRunPain;
    _sharp = existing?.acuteSharpPain;
    _stiff = existing?.morningStiffness;
    _baseline = existing?.morningBaselineCleared;
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: AbsorbPointer(
        absorbing: _save.isLoading,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pain check-in',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              '${_morning ? 'Next morning' : 'After run'} · ${widget.activity.name}',
            ),
            const SizedBox(height: 24),
            RehabPainInput(
              value: _pain,
              onChanged: (v) => setState(() => _pain = v),
            ),
            ..._questions(),
            if (_needsHistoricTime)
              RehabHistoricalTime(
                earliest: widget.activity.date,
                latest:
                    widget.existing?.morningAfterRecordedAt ??
                    widget.activity.date,
                value: _historicalTime,
                onChanged: (v) => setState(() => _historicalTime = v),
              ),
            ..._actions(),
          ],
        ),
      ),
    ),
  );

  List<Widget> _actions() => [
    if (_save.hasError)
      Semantics(
        liveRegion: true,
        child: const Text(
          'Could not save check-in. Your answers are kept. Try again.',
        ),
      ),
    const SizedBox(height: 16),
    FilledButton(
      onPressed: _complete && !_save.isLoading ? _submit : null,
      child: Text(_save.isLoading ? 'Saving…' : 'Save check-in'),
    ),
    TextButton(
      onPressed: () => Navigator.pop(context),
      child: const Text('Cancel'),
    ),
  ];

  List<Widget> _questions() => _morning
      ? [
          RehabYesNo(
            label: 'Morning stiffness?',
            fieldKey: 'stiffness',
            value: _stiff,
            onChanged: (v) => setState(() => _stiff = v),
          ),
          RehabYesNo(
            label: 'Back to your usual symptom baseline?',
            fieldKey: 'baseline',
            value: _baseline,
            onChanged: (v) => setState(() => _baseline = v),
          ),
        ]
      : [
          RehabYesNo(
            label: 'Any acute sharp pain?',
            fieldKey: 'sharp-pain',
            value: _sharp,
            onChanged: (v) => setState(() => _sharp = v),
          ),
          const Text('Sharp pain: stop running and seek professional advice.'),
        ];

  Future<void> _submit() async {
    setState(() => _save = const AsyncLoading());
    try {
      final now = ref.read(rehabTimeProvider).value ?? DateTime.now();
      final existing = widget.existing;
      final record = RehabFeedback(
        id:
            existing?.id ??
            'rehab:${widget.activity.id}:${widget.program.injurySite.name}',
        activityId: widget.activity.id,
        injurySite: widget.program.injurySite,
        postRunPain: _morning ? existing?.postRunPain : _pain,
        acuteSharpPain: _morning ? existing?.acuteSharpPain : _sharp,
        postRunRecordedAt: _morning
            ? existing?.postRunRecordedAt
            : existing?.postRunRecordedAt ?? _historicalTime ?? now,
        morningAfterPain: _morning ? _pain : existing?.morningAfterPain,
        morningStiffness: _morning ? _stiff : existing?.morningStiffness,
        morningBaselineCleared: _morning
            ? _baseline
            : existing?.morningBaselineCleared,
        morningAfterRecordedAt: _morning
            ? existing?.morningAfterRecordedAt ?? now
            : existing?.morningAfterRecordedAt,
      );
      await ref.read(rehabJournalProvider.notifier).saveFeedback(record);
      if (mounted) Navigator.pop(context);
    } catch (error, stack) {
      if (mounted) setState(() => _save = AsyncError(error, stack));
    }
  }
}
