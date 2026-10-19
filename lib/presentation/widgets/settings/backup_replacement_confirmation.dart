import 'package:flutter/material.dart';

class BackupReplacementConfirmation extends StatelessWidget {
  const BackupReplacementConfirmation({super.key});
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Delete local data and restore?'),
    semanticLabel: 'Confirm replacement of all backup-owned local data',
    scrollable: true,
    content: const Text(
      'All local profile settings, activities, heart rate streams, training plans, shoes, assignments and rehab feedback will be replaced with this file. Local records missing from the file will be deleted. Your login and onboarding stay on this device.',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Keep local data'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.error,
          foregroundColor: Theme.of(context).colorScheme.onError,
        ),
        onPressed: () => Navigator.pop(context, true),
        child: const Text('Delete local data and restore'),
      ),
    ],
  );
}
