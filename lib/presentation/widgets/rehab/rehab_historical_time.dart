import 'package:flutter/material.dart';

class RehabHistoricalTime extends StatelessWidget {
  final DateTime earliest;
  final DateTime latest;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  const RehabHistoricalTime({
    super.key,
    required this.earliest,
    required this.latest,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Recall when you observed the after-run symptoms. '
        'Choose a time before the saved morning check-in.',
      ),
      TextButton(
        onPressed: () => _choose(context),
        child: Text(
          value == null
              ? 'Choose observation time'
              : 'Observation: ${value?.toLocal()}',
        ),
      ),
    ],
  );

  Future<void> _choose(BuildContext context) async {
    final first = earliest.toLocal();
    final last = latest.toLocal();
    final day = await showDatePicker(
      context: context,
      initialDate: value?.toLocal() ?? first,
      firstDate: first,
      lastDate: last,
    );
    if (day == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value?.toLocal() ?? first),
    );
    if (time == null || !context.mounted) return;
    final chosen = DateTime(
      day.year,
      day.month,
      day.day,
      time.hour,
      time.minute,
    );
    if (chosen.isBefore(first) || chosen.isAfter(last)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose a time between the run and morning check-in.'),
        ),
      );
      return;
    }
    onChanged(chosen);
  }
}
