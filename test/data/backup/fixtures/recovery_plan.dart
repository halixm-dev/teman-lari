import 'package:teman_lari/data/backup/archive/training_plan_config_archive.dart';
import 'package:teman_lari/domain/usecases/training_plan_config.dart';

Map<String, Object?> recoveryPlan(String goal) => {
  'active_state': {
    'plans': [
      {
        'id': 'active',
        'plan': {
          'start_date': '2026-10-14',
          'days': [],
          'goal': goal,
          'description': 'Recovery sentinel',
          'week_in_cycle': -1,
          'cycle_phase': 'beginner',
        },
      },
    ],
    'active_plan_id': 'active',
    'configuration': TrainingPlanConfigArchive.fromDomain(
      TrainingPlanConfig.defaultConfig,
    ).toJson(),
    'week_in_cycle': {'value': null, 'modified_at': null},
    'cycle_start_date': {'value': null, 'modified_at': null},
    'modified_at': null,
  },
};

Object? recoveryPlanGoal(Map<String, Object?>? records) {
  final state = records?['active_state'] as Map;
  final record = (state['plans'] as List).single as Map;
  return (record['plan'] as Map)['goal'];
}
