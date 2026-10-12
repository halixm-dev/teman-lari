import '../entities/activity.dart';

abstract class ActivityRepository {
  Future<List<Activity>> getAllActivities({int monthsBack = 12});
  Future<void> refreshActivities({int monthsBack = 12});
  Future<Map<int, List<double>>> getHeartRateStreams(List<int> activityIds);
  Future<Activity> uploadActivity(int localId);
  Future<void> saveActivity(Activity activity);
}
