import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/rehab_feedback.dart';
import '../../../domain/entities/rehab_program.dart';
import '../../../domain/entities/running_stats.dart';
import '../../../domain/usecases/start_rehab_program.dart';
import '../../providers/rehab_provider.dart';
import '../../providers/training_plan_provider.dart';
import 'rehab_labels.dart';

Future<void> showRehabSetup(
  BuildContext context, {
  required RunningStats stats,
  ReturnModality mode = ReturnModality.walkRun,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _RehabSetupSheet(stats: stats, mode: mode),
);

class _RehabSetupSheet extends ConsumerStatefulWidget {
  final RunningStats stats;
  final ReturnModality mode;
  const _RehabSetupSheet({required this.stats, required this.mode});
  @override
  ConsumerState<_RehabSetupSheet> createState() => _RehabSetupSheetState();
}

class _RehabSetupSheetState extends ConsumerState<_RehabSetupSheet> {
  InjurySite? _site;
  late ReturnModality _mode = widget.mode;
  AsyncValue<void> _save = const AsyncData(null);
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Start return-to-run',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const Text(
            'Easy sessions with after-run and next-morning check-ins. '
            'Your observations control progression; finishing needs your confirmation.',
          ),
          const SizedBox(height: 24),
          _injuryField(),
          const SizedBox(height: 16),
          RehabModeField(
            mode: _mode,
            fieldKey: 'rehab-setup-mode',
            onChanged: _save.isLoading
                ? null
                : (v) {
                    if (v != null) setState(() => _mode = v);
                  },
          ),
          const SizedBox(height: 24),
          if (_save.hasError)
            const Text('Could not start return-to-run. Try again.'),
          FilledButton(
            onPressed: _site == null || _save.isLoading ? null : _submit,
            child: Text(_save.isLoading ? 'Starting…' : 'Start return plan'),
          ),
          TextButton(
            onPressed: _save.isLoading ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    ),
  );

  Widget _injuryField() => DropdownButtonFormField<InjurySite>(
    key: const Key('rehab-injury-site'),
    isExpanded: true,
    itemHeight: null,
    decoration: const InputDecoration(labelText: 'Affected area'),
    items: [
      for (final site in InjurySite.values)
        DropdownMenuItem(value: site, child: Text(injurySiteLabel(site))),
    ],
    onChanged: _save.isLoading ? null : (v) => setState(() => _site = v),
  );

  Future<void> _submit() async {
    final site = _site;
    if (site == null) return;
    setState(() => _save = const AsyncLoading());
    try {
      final program = startRehabProgram(
        stats: widget.stats,
        injurySite: site,
        mode: _mode,
        now: ref.read(rehabTimeProvider).value ?? DateTime.now(),
        config: ref.read(trainingPlanConfigProvider),
      );
      await ref.read(rehabJournalProvider.notifier).start(program);
      if (mounted) Navigator.pop(context);
    } catch (error, stack) {
      if (mounted) setState(() => _save = AsyncError(error, stack));
    }
  }
}
