import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RehabAsyncButton extends StatefulWidget {
  final String label;
  final Future<void> Function() onPressed;
  const RehabAsyncButton({
    super.key,
    required this.label,
    required this.onPressed,
  });
  @override
  State<RehabAsyncButton> createState() => _RehabAsyncButtonState();
}

class _RehabAsyncButtonState extends State<RehabAsyncButton> {
  AsyncValue<void> _action = const AsyncData(null);
  @override
  Widget build(BuildContext context) => Column(
    children: [
      FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
        onPressed: _action.isLoading ? null : _submit,
        child: Text(_action.isLoading ? 'Updating…' : widget.label),
      ),
      if (_action.hasError)
        const Text('Could not update return-to-run. Try again.'),
    ],
  );

  Future<void> _submit() async {
    setState(() => _action = const AsyncLoading());
    try {
      await widget.onPressed();
      if (mounted) setState(() => _action = const AsyncData(null));
    } catch (error, stack) {
      if (mounted) setState(() => _action = AsyncError(error, stack));
    }
  }
}
