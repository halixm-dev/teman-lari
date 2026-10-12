import '../../core/network/strava_api_client.dart';
import '../models/activity_model.dart';
import '../models/activity_streams.dart';
import '../models/athlete_model.dart';

class StravaActivityDataSource {
  final StravaApiClient _client;

  StravaActivityDataSource(this._client);

  Future<List<ActivityModel>> getAllActivities({int monthsBack = 12}) async {
    final allActivities = <ActivityModel>[];
    final after =
        DateTime.now()
            .subtract(Duration(days: 30 * monthsBack))
            .millisecondsSinceEpoch ~/
        1000;

    int page = 1;
    while (true) {
      final data = await _client.getList(
        'athlete/activities',
        params: {
          'after': after.toString(),
          'per_page': '200',
          'page': page.toString(),
        },
      );

      if (data.isEmpty) break;

      final runningActivities = data
          .map((a) => ActivityModel.fromJson(a as Map<String, dynamic>))
          .toList();

      allActivities.addAll(runningActivities);

      if (data.length < 200) break;
      page++;
    }

    return allActivities;
  }

  Future<ActivityStreams> getActivityStreams(int activityId) async {
    final data = await _client.get(
      'activities/$activityId/streams',
      params: {
        'keys': 'time,heartrate,cadence,velocity_smooth,altitude',
        'key_by_type': 'true',
      },
    );
    return ActivityStreams.fromJson(data);
  }

  Future<AthleteModel> getAthlete() async {
    final data = await _client.get('athlete');
    return AthleteModel.fromJson(data);
  }

  Future<ActivityModel> createActivity({
    required String name,
    required String type,
    required String startDateLocal,
    required int elapsedTime,
    double? distance,
    String? description,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'type': type,
      'sport_type': type,
      'start_date_local': startDateLocal,
      'elapsed_time': elapsedTime,
    };
    if (distance != null) {
      body['distance'] = distance;
    }
    if (description != null) {
      body['description'] = description;
    }
    final data = await _client.post('activities', body: body);
    return ActivityModel.fromJson(data);
  }
}
