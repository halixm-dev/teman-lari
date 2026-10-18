/// Changes computed from the selected archive and the coordinated local state.
class BackupImportSummary {
  final int addedActivities;
  final int matchedActivities;
  final int retainedConflicts;
  final int changedPreferences;
  final bool changedTrainingPlan;
  final int addedShoes;
  final int updatedShoes;
  final int addedFeedback;
  final int updatedFeedback;
  final int changedAssignments;
  final List<String> warnings;
  const BackupImportSummary({
    this.addedActivities = 0,
    this.matchedActivities = 0,
    this.retainedConflicts = 0,
    this.changedPreferences = 0,
    this.addedShoes = 0,
    this.updatedShoes = 0,
    this.addedFeedback = 0,
    this.updatedFeedback = 0,
    this.changedAssignments = 0,
    this.changedTrainingPlan = false,
    this.warnings = const [],
  });
}
