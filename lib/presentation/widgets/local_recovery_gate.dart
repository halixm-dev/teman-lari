import 'package:flutter/material.dart';

/// Normal providers are created only once local recovery has completed.
class LocalRecoveryGate extends StatefulWidget {
  final Future<void> Function() initialize;
  final Widget Function() ready;

  const LocalRecoveryGate({
    super.key,
    required this.initialize,
    required this.ready,
  });

  @override
  State<LocalRecoveryGate> createState() => _LocalRecoveryGateState();
}

class _LocalRecoveryGateState extends State<LocalRecoveryGate> {
  late Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = widget.initialize();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _initialization,
    builder: (context, state) {
      if (state.connectionState == ConnectionState.done && !state.hasError) {
        return widget.ready();
      }
      return MaterialApp(
        home: Scaffold(body: Center(child: _status(state.hasError))),
      );
    },
  );

  Widget _status(bool failed) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!failed) const CircularProgressIndicator(),
        Text(
          failed
              ? 'Local data recovery could not finish. Your recovery copy is kept.'
              : 'Checking local data recovery…',
        ),
        if (failed)
          FilledButton(
            onPressed: () =>
                setState(() => _initialization = widget.initialize()),
            child: const Text('Retry recovery'),
          ),
      ],
    ),
  );
}
