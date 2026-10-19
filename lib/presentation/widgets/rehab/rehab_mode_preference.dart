import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/rehab_program.dart';
import '../../providers/rehab_provider.dart';
import 'rehab_labels.dart';

class RehabModePreference extends ConsumerStatefulWidget {
  final ReturnModality mode;
  const RehabModePreference({super.key, required this.mode});
  @override
  ConsumerState<RehabModePreference> createState() =>
      _RehabModePreferenceState();
}

class _RehabModePreferenceState extends ConsumerState<RehabModePreference> {
  AsyncValue<void> _save = const AsyncData(null);
  @override
  Widget build(BuildContext context) => Column(
    children: [
      RehabModeField(
        key: ValueKey(widget.mode),
        mode: widget.mode,
        fieldKey: 'rehab-current-mode',
        onChanged: _save.isLoading ? null : _change,
      ),
      if (_save.hasError)
        const Text('Could not change your preference. Try again.'),
    ],
  );

  Future<void> _change(ReturnModality? mode) async {
    if (mode == null) return;
    setState(() => _save = const AsyncLoading());
    try {
      await ref.read(rehabJournalProvider.notifier).changeMode(mode);
      if (mounted) setState(() => _save = const AsyncData(null));
    } catch (error, stack) {
      if (mounted) setState(() => _save = AsyncError(error, stack));
    }
  }
}
