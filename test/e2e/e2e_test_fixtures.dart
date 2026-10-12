import 'dart:convert';
import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teman_lari/data/datasources/local_activity_datasource.dart';
import 'package:teman_lari/data/datasources/preferences_storage.dart';
import 'package:teman_lari/data/datasources/token_storage.dart';
import 'package:teman_lari/data/models/activity_model.dart';
import 'package:teman_lari/data/models/athlete_model.dart';
import 'package:teman_lari/data/models/strava_tokens.dart';
import 'package:teman_lari/domain/entities/activity.dart';
import 'package:teman_lari/domain/usecases/generate_plan_usecase.dart';
import 'package:teman_lari/domain/usecases/training_load_calculator.dart';

export 'package:teman_lari/data/models/activity_model.dart';
export 'package:teman_lari/data/models/athlete_model.dart';
export 'package:teman_lari/data/models/strava_tokens.dart';
export 'package:teman_lari/domain/entities/activity.dart';
export 'package:teman_lari/domain/entities/training_plan.dart';
export 'package:teman_lari/domain/entities/running_stats.dart';

/// Fake TokenStorage operating in-memory for deterministic E2E testing
class FakeTokenStorage extends TokenStorage {
  StravaTokens? _tokens;
  int clearTokensCallCount = 0;
  int saveTokensCallCount = 0;

  @override
  Future<void> saveTokens(StravaTokens tokens) async {
    _tokens = tokens;
    saveTokensCallCount++;
  }

  @override
  Future<StravaTokens?> getTokens() async {
    return _tokens;
  }

  @override
  Future<void> clearTokens() async {
    _tokens = null;
    clearTokensCallCount++;
  }

  void seedTokens(StravaTokens tokens) {
    _tokens = tokens;
  }
}

/// Simulated Strava API request log for verifying upload and background upload constraints
class RecordedApiRequest {
  final String method;
  final String endpoint;
  final Map<String, dynamic>? body;
  final Map<String, String>? headers;

  const RecordedApiRequest({
    required this.method,
    required this.endpoint,
    this.body,
    this.headers,
  });
}

/// Fake Strava API client simulator for testing Selective Push and sync responses
class FakeStravaApiClient {
  final List<RecordedApiRequest> recordedRequests = [];
  bool simulateRateLimit429 = false;
  bool simulateNetworkError = false;
  bool simulateTokenRevoked401 = false;
  int nextRemoteId = 8849201;

  void reset() {
    recordedRequests.clear();
    simulateRateLimit429 = false;
    simulateNetworkError = false;
    simulateTokenRevoked401 = false;
  }

  Future<Map<String, dynamic>> postActivity(
    Map<String, dynamic> payload, {
    String? token,
  }) async {
    recordedRequests.add(
      RecordedApiRequest(
        method: 'POST',
        endpoint: 'activities',
        body: payload,
        headers: token != null ? {'Authorization': 'Bearer $token'} : null,
      ),
    );

    if (simulateNetworkError) {
      throw const SocketException(
        'Simulated network failure: host unreachable',
      );
    }

    if (simulateRateLimit429) {
      throw const HttpException('Rate limit reached (15-min limit)');
    }

    if (simulateTokenRevoked401) {
      throw const HttpException('Authorization Error: token revoked');
    }

    // Return Strava activity creation response
    final remoteId = nextRemoteId++;
    return {
      'id': remoteId,
      'name': payload['name'] ?? 'Uploaded Run',
      'distance': payload['distance'] ?? 5000.0,
      'moving_time': payload['elapsed_time'] ?? 1500,
      'elapsed_time': payload['elapsed_time'] ?? 1500,
      'type': payload['sport_type'] ?? 'Run',
      'sport_type': payload['sport_type'] ?? 'Run',
      'start_date_local':
          payload['start_date_local'] ?? DateTime.now().toIso8601String(),
    };
  }
}

/// Comprehensive E2E Test Harness providing sandboxed storage, fixtures, and contracts
class E2ETestHarness {
  late Directory tempDir;
  late LocalActivityDataSource localDataSource;
  late FakeTokenStorage tokenStorage;
  late PreferencesStorage preferencesStorage;
  late FakeStravaApiClient fakeStravaApiClient;
  late TrainingLoadCalculator trainingLoadCalculator;
  late GeneratePlanUseCase generatePlanUseCase;

  bool _initialized = false;

  Future<void> setUp() async {
    tempDir = await Directory.systemTemp.createTemp('teman_lari_e2e_');
    Hive.init(tempDir.path);

    localDataSource = LocalActivityDataSource();
    tokenStorage = FakeTokenStorage();
    SharedPreferences.setMockInitialValues({});
    preferencesStorage = PreferencesStorage();
    fakeStravaApiClient = FakeStravaApiClient();
    trainingLoadCalculator = TrainingLoadCalculator();
    generatePlanUseCase = GeneratePlanUseCase();
    _initialized = true;
  }

  Future<void> tearDown() async {
    if (_initialized) {
      await Hive.close();
      if (await tempDir.exists()) {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      }
      _initialized = false;
    }
  }

  // ==========================================
  // Smart Merge Reference Engine (ADR 0007 / ADR 0008 / R3)
  // ==========================================

  /// Saves activities into Hive safely using String keys so negative IDs are stored without HiveError
  Future<void> saveActivities(List<ActivityModel> activities) async {
    final box = await localDataSource.activitiesBox;
    final now = DateTime.now().millisecondsSinceEpoch;
    final entries = <String, Map<String, dynamic>>{};
    for (final activity in activities) {
      entries[activity.id.toString()] = {
        'id': activity.id,
        'data': jsonEncode(activity.toJson()),
        'synced_at': now,
      };
    }
    await box.putAll(entries);
  }

  /// Reconciles incoming remote activities with local Hive activities
  /// Additive union: preserves id < 0 unconditionally; updates or inserts matching positive IDs
  Future<void> executeSmartMerge(List<ActivityModel> remoteActivities) async {
    final box = await localDataSource.activitiesBox;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Read current raw records from Hive
    final existingList = <Map<String, dynamic>>[];
    for (final key in box.keys) {
      final val = box.get(key);
      if (val is Map) {
        existingList.add(Map<String, dynamic>.from(val));
      }
    }

    // Retain all local-only workouts (id < 0) unconditionally
    final mergedMap = <String, Map<String, dynamic>>{};
    for (final record in existingList) {
      final id = record['id'] as int;
      if (id < 0) {
        mergedMap[id.toString()] = record;
      }
    }

    // Merge remote activities additively (matching on positive id)
    for (final remote in remoteActivities) {
      mergedMap[remote.id.toString()] = {
        'id': remote.id,
        'data': jsonEncode(remote.toJson()),
        'synced_at': now,
      };
    }

    // Write back to Hive using String keys
    await box.clear();
    await box.putAll(mergedMap);
  }

  /// Re-keys a local negative-ID workout to a positive remote Strava ID upon successful Selective Push
  Future<void> associateRemoteId({
    required int oldLocalId,
    required int remoteId,
    required ActivityModel updatedModel,
  }) async {
    final box = await localDataSource.activitiesBox;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Remove old key (both int and string key)
    await box.delete(oldLocalId);
    await box.delete(oldLocalId.toString());

    // Save with new positive remote ID
    await box.put(remoteId.toString(), {
      'id': remoteId,
      'data': jsonEncode(updatedModel.toJson()),
      'synced_at': now,
    });
  }

  /// Retrieves all activities stored in Hive without 1-hour TTL expiration (ADR 0007 Zero-TTL SSOT)
  Future<List<ActivityModel>> getAllStoredActivities() async {
    final box = await localDataSource.activitiesBox;
    if (box.isEmpty) return [];

    final list = <ActivityModel>[];
    for (final val in box.values) {
      if (val is Map) {
        final raw = val['data'] as String;
        list.add(ActivityModel.fromJson(jsonDecode(raw)));
      }
    }

    // Sort descending by ID or date
    list.sort((a, b) => b.startDate.compareTo(a.startDate));
    return list;
  }

  // ==========================================
  // Model & Entity Fixture Builders
  // ==========================================

  ActivityModel createLocalActivityModel({
    int? id,
    String name = 'Local Morning Run',
    String type = 'Run',
    double distance = 5000.0,
    int movingTime = 1500,
    int elapsedTime = 1550,
    double totalElevationGain = 45.0,
    DateTime? date,
    double averageSpeed = 3.33,
    double maxSpeed = 4.2,
    double? averageHeartrate = 148.0,
    double? maxHeartrate = 168.0,
    double? averageCadence = 84.0,
    int? sufferScore = 24,
    bool hasHeartrate = true,
  }) {
    final localDate = date ?? DateTime.now();
    final localId = id ?? -localDate.millisecondsSinceEpoch;
    return ActivityModel(
      id: localId,
      name: name,
      type: type,
      distance: distance,
      movingTime: movingTime,
      elapsedTime: elapsedTime,
      totalElevationGain: totalElevationGain,
      startDate: localDate.toUtc().toIso8601String(),
      averageSpeed: averageSpeed,
      maxSpeed: maxSpeed,
      averageHeartrate: averageHeartrate,
      maxHeartrate: maxHeartrate,
      averageCadence: averageCadence,
      sufferScore: sufferScore,
      hasHeartrate: hasHeartrate,
    );
  }

  ActivityModel createRemoteActivityModel({
    required int id,
    String name = 'Strava Trail Run',
    String type = 'Run',
    double distance = 8000.0,
    int movingTime = 2400,
    int elapsedTime = 2500,
    double totalElevationGain = 120.0,
    DateTime? date,
    double averageSpeed = 3.33,
    double maxSpeed = 4.5,
    double? averageHeartrate = 155.0,
    double? maxHeartrate = 175.0,
    double? averageCadence = 85.0,
    int? sufferScore = 38,
    bool hasHeartrate = true,
  }) {
    final remoteDate = date ?? DateTime.now().subtract(const Duration(days: 1));
    return ActivityModel(
      id: id,
      name: name,
      type: type,
      distance: distance,
      movingTime: movingTime,
      elapsedTime: elapsedTime,
      totalElevationGain: totalElevationGain,
      startDate: remoteDate.toUtc().toIso8601String(),
      averageSpeed: averageSpeed,
      maxSpeed: maxSpeed,
      averageHeartrate: averageHeartrate,
      maxHeartrate: maxHeartrate,
      averageCadence: averageCadence,
      sufferScore: sufferScore,
      hasHeartrate: hasHeartrate,
    );
  }

  Activity modelToEntity(ActivityModel model, {int maxHr = 190}) {
    final date = DateTime.parse(model.startDate).toLocal();
    final distanceKm = model.distance / 1000.0;
    final movingTimeSeconds = model.movingTime;
    final paceSecondsPerKm =
        movingTimeSeconds / (distanceKm > 0 ? distanceKm : 1);

    TrainingLoad load;
    if (model.averageHeartrate != null) {
      final hrPercent = model.averageHeartrate! / maxHr;
      if (hrPercent < 0.70) {
        load = TrainingLoad.easy;
      } else if (hrPercent < 0.80) {
        load = TrainingLoad.moderate;
      } else if (hrPercent < 0.90) {
        load = TrainingLoad.hard;
      } else {
        load = TrainingLoad.veryHard;
      }
    } else {
      load = TrainingLoad.moderate;
    }

    ActivityType parsedType;
    switch (model.type) {
      case 'Run':
        parsedType = ActivityType.run;
        break;
      case 'Ride':
      case 'VirtualRide':
        parsedType = ActivityType.ride;
        break;
      case 'Walk':
        parsedType = ActivityType.walk;
        break;
      default:
        parsedType = ActivityType.other;
    }

    return Activity(
      id: model.id,
      name: model.name,
      date: date,
      type: parsedType,
      distanceKm: distanceKm,
      movingTime: Duration(seconds: movingTimeSeconds),
      pace: Duration(seconds: paceSecondsPerKm.round()),
      elevationGainM: model.totalElevationGain,
      trainingLoad: load,
      avgHeartRate: model.averageHeartrate,
      maxHeartRate: model.maxHeartrate,
      avgCadence: model.averageCadence,
      sufferScore: model.sufferScore,
    );
  }

  StravaTokens createSampleTokens({
    String accessToken = 'sample_access_token_12345',
    String refreshToken = 'sample_refresh_token_67890',
    int? expiresAt,
  }) {
    final exp =
        expiresAt ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000 + 21600);
    return StravaTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: exp,
    );
  }

  AthleteModel createSampleAthlete({
    int id = 9876543,
    String firstName = 'Budi',
    String lastName = 'Santoso',
    double? maxHeartrate = 188.0,
    String? dateOfBirth = '1992-04-15',
  }) {
    return AthleteModel(
      id: id,
      firstName: firstName,
      lastName: lastName,
      maxHeartrate: maxHeartrate,
      dateOfBirth: dateOfBirth,
    );
  }
}
