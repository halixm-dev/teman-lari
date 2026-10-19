import 'package:flutter/material.dart';
import '../../../domain/entities/rehab_feedback.dart';
import '../../../domain/entities/rehab_program.dart';

String injurySiteLabel(InjurySite site) => switch (site) {
  InjurySite.achilles => 'Achilles',
  InjurySite.knee => 'Knee',
  InjurySite.shin => 'Shin',
  InjurySite.plantarFascia => 'Plantar fascia',
  InjurySite.hamstring => 'Hamstring',
};

String returnModeLabel(ReturnModality mode) => switch (mode) {
  ReturnModality.walkRun => 'Walk/run intervals',
  ReturnModality.continuous => 'Continuous easy runs',
};

class RehabModeField extends StatelessWidget {
  final ReturnModality mode;
  final ValueChanged<ReturnModality?>? onChanged;
  final String fieldKey;
  const RehabModeField({
    super.key,
    required this.mode,
    required this.onChanged,
    required this.fieldKey,
  });
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<ReturnModality>(
    key: Key(fieldKey),
    initialValue: mode,
    isExpanded: true,
    itemHeight: null,
    decoration: const InputDecoration(labelText: 'Preferred return sessions'),
    items: [
      for (final mode in ReturnModality.values)
        DropdownMenuItem(value: mode, child: Text(returnModeLabel(mode))),
    ],
    onChanged: onChanged,
  );
}
