import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Startup waits for recovery; runtime recovery keeps authentication mounted.
class LocalRecoveryGate extends StatefulWidget {
  final Future<void> Function() initialize;
  final Widget Function() ready;
  final ValueListenable<bool>? recoveryRequired;

  const LocalRecoveryGate({
    super.key,
    required this.initialize,
    required this.ready,
    this.recoveryRequired,
  });

  @override
  State<LocalRecoveryGate> createState() => _LocalRecoveryGateState();
}

class _LocalRecoveryGateState extends State<LocalRecoveryGate> {
  late Future<void> _initialization;
  Widget? _ready;

  @override
  void initState() {
    super.initState();
    _initialization = widget.initialize();
    widget.recoveryRequired?.addListener(_recoveryChanged);
  }

  @override
  void didUpdateWidget(LocalRecoveryGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recoveryRequired != widget.recoveryRequired) {
      oldWidget.recoveryRequired?.removeListener(_recoveryChanged);
      widget.recoveryRequired?.addListener(_recoveryChanged);
    }
  }

  @override
  void dispose() {
    widget.recoveryRequired?.removeListener(_recoveryChanged);
    super.dispose();
  }

  void _recoveryChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _initialization,
    builder: (context, state) {
      final complete = state.connectionState == ConnectionState.done;
      final recoveryRequired = widget.recoveryRequired?.value ?? false;
      final blocked = !complete || state.hasError || recoveryRequired;
      if (!blocked) _ready ??= widget.ready();
      final ready = _ready;
      final status = MaterialApp(
        home: Scaffold(body: Center(child: _status(complete && blocked))),
      );
      if (ready == null) return status;
      return Stack(
        alignment: Alignment.topLeft,
        fit: StackFit.expand,
        children: [
          Offstage(
            offstage: blocked,
            child: TickerMode(
              enabled: !blocked,
              child: ExcludeFocus(
                excluding: blocked,
                child: ExcludeSemantics(excluding: blocked, child: ready),
              ),
            ),
          ),
          if (blocked) status,
        ],
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
            onPressed: () {
              final initialization = widget.initialize();
              setState(() {
                _initialization = initialization;
              });
            },
            child: const Text('Retry recovery'),
          ),
      ],
    ),
  );
}
