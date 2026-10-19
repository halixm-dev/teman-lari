import 'package:flutter/material.dart';

enum CheckInWindow { postRun, morningAfter }

class RehabYesNo extends StatelessWidget {
  final String label;
  final String fieldKey;
  final bool? value;
  final ValueChanged<bool> onChanged;
  const RehabYesNo({
    super.key,
    required this.label,
    required this.fieldKey,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: [
            for (final answer in [true, false])
              Semantics(
                label: '$label ${answer ? 'Yes' : 'No'}',
                button: true,
                selected: value == answer,
                onTap: () => onChanged(answer),
                excludeSemantics: true,
                child: ChoiceChip(
                  key: Key('$fieldKey-${answer ? 'yes' : 'no'}'),
                  label: Text(answer ? 'Yes' : 'No'),
                  selected: value == answer,
                  onSelected: (_) => onChanged(answer),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

class RehabPainInput extends StatelessWidget {
  final double? value;
  final ValueChanged<double> onChanged;
  const RehabPainInput({
    super.key,
    required this.value,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value == null
            ? 'Choose a pain score'
            : 'Pain: ${value?.toStringAsFixed(1)} / 10',
      ),
      Semantics(
        label: 'Pain score',
        child: Slider(
          value: value ?? 0,
          min: 0,
          max: 10,
          divisions: 100,
          label: value?.toStringAsFixed(1),
          semanticFormatterCallback: (v) => '${v.toStringAsFixed(1)} out of 10',
          onChanged: onChanged,
        ),
      ),
      const Text('0 = no pain · 10 = worst pain imaginable'),
      TextButton(
        onPressed: () => onChanged(0),
        child: const Text('No pain (0)'),
      ),
    ],
  );
}
