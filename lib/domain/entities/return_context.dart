import 'rehab_progress.dart';

enum GapCategory { none, short, long, injury, extended }

class ReturnContext {
  final int gapDays;
  final GapCategory category;
  final double preGapAvgKm;
  final double preGapAvgMin;
  final DateTime? lastActivityDate;
  final bool isStale;
  final RehabProgress? rehabilitation;

  const ReturnContext({
    required this.gapDays,
    required this.category,
    this.preGapAvgKm = 0,
    this.preGapAvgMin = 0,
    this.lastActivityDate,
    this.isStale = false,
    this.rehabilitation,
  });

  bool get isReturning => category != GapCategory.none;

  int get rampWeeks {
    return switch (category) {
      GapCategory.none => 0,
      GapCategory.short => 1,
      GapCategory.long => 2,
      GapCategory.injury => 3,
      GapCategory.extended => 0, // treated as beginner, not return ramp
    };
  }

  double get startVolumeFraction {
    return switch (category) {
      GapCategory.none => 1.0,
      GapCategory.short => 0.85,
      GapCategory.long => 0.70,
      GapCategory.injury => 0.55,
      GapCategory.extended => 0, // beginner reset
    };
  }

  factory ReturnContext.empty() =>
      const ReturnContext(gapDays: 0, category: GapCategory.none);
}
