// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'activity_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ActivityModel {

 int get id; String get name; String get type; double get distance; int get movingTime; int get elapsedTime; double get totalElevationGain; String get startDate; double get averageSpeed; double get maxSpeed; double? get averageHeartrate; double? get maxHeartrate; double? get averageCadence; int? get sufferScore; bool get hasHeartrate; int? get workoutType; double? get perceivedExertion; String? get shoeId; DateTime? get shoeAssignmentModifiedAt;
/// Create a copy of ActivityModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ActivityModelCopyWith<ActivityModel> get copyWith => _$ActivityModelCopyWithImpl<ActivityModel>(this as ActivityModel, _$identity);

  /// Serializes this ActivityModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ActivityModel&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.distance, distance) || other.distance == distance)&&(identical(other.movingTime, movingTime) || other.movingTime == movingTime)&&(identical(other.elapsedTime, elapsedTime) || other.elapsedTime == elapsedTime)&&(identical(other.totalElevationGain, totalElevationGain) || other.totalElevationGain == totalElevationGain)&&(identical(other.startDate, startDate) || other.startDate == startDate)&&(identical(other.averageSpeed, averageSpeed) || other.averageSpeed == averageSpeed)&&(identical(other.maxSpeed, maxSpeed) || other.maxSpeed == maxSpeed)&&(identical(other.averageHeartrate, averageHeartrate) || other.averageHeartrate == averageHeartrate)&&(identical(other.maxHeartrate, maxHeartrate) || other.maxHeartrate == maxHeartrate)&&(identical(other.averageCadence, averageCadence) || other.averageCadence == averageCadence)&&(identical(other.sufferScore, sufferScore) || other.sufferScore == sufferScore)&&(identical(other.hasHeartrate, hasHeartrate) || other.hasHeartrate == hasHeartrate)&&(identical(other.workoutType, workoutType) || other.workoutType == workoutType)&&(identical(other.perceivedExertion, perceivedExertion) || other.perceivedExertion == perceivedExertion)&&(identical(other.shoeId, shoeId) || other.shoeId == shoeId)&&(identical(other.shoeAssignmentModifiedAt, shoeAssignmentModifiedAt) || other.shoeAssignmentModifiedAt == shoeAssignmentModifiedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,name,type,distance,movingTime,elapsedTime,totalElevationGain,startDate,averageSpeed,maxSpeed,averageHeartrate,maxHeartrate,averageCadence,sufferScore,hasHeartrate,workoutType,perceivedExertion,shoeId,shoeAssignmentModifiedAt]);

@override
String toString() {
  return 'ActivityModel(id: $id, name: $name, type: $type, distance: $distance, movingTime: $movingTime, elapsedTime: $elapsedTime, totalElevationGain: $totalElevationGain, startDate: $startDate, averageSpeed: $averageSpeed, maxSpeed: $maxSpeed, averageHeartrate: $averageHeartrate, maxHeartrate: $maxHeartrate, averageCadence: $averageCadence, sufferScore: $sufferScore, hasHeartrate: $hasHeartrate, workoutType: $workoutType, perceivedExertion: $perceivedExertion, shoeId: $shoeId, shoeAssignmentModifiedAt: $shoeAssignmentModifiedAt)';
}


}

/// @nodoc
abstract mixin class $ActivityModelCopyWith<$Res>  {
  factory $ActivityModelCopyWith(ActivityModel value, $Res Function(ActivityModel) _then) = _$ActivityModelCopyWithImpl;
@useResult
$Res call({
 int id, String name, String type, double distance, int movingTime, int elapsedTime, double totalElevationGain, String startDate, double averageSpeed, double maxSpeed, double? averageHeartrate, double? maxHeartrate, double? averageCadence, int? sufferScore, bool hasHeartrate, int? workoutType, double? perceivedExertion, String? shoeId, DateTime? shoeAssignmentModifiedAt
});




}
/// @nodoc
class _$ActivityModelCopyWithImpl<$Res>
    implements $ActivityModelCopyWith<$Res> {
  _$ActivityModelCopyWithImpl(this._self, this._then);

  final ActivityModel _self;
  final $Res Function(ActivityModel) _then;

/// Create a copy of ActivityModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? type = null,Object? distance = null,Object? movingTime = null,Object? elapsedTime = null,Object? totalElevationGain = null,Object? startDate = null,Object? averageSpeed = null,Object? maxSpeed = null,Object? averageHeartrate = freezed,Object? maxHeartrate = freezed,Object? averageCadence = freezed,Object? sufferScore = freezed,Object? hasHeartrate = null,Object? workoutType = freezed,Object? perceivedExertion = freezed,Object? shoeId = freezed,Object? shoeAssignmentModifiedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,distance: null == distance ? _self.distance : distance // ignore: cast_nullable_to_non_nullable
as double,movingTime: null == movingTime ? _self.movingTime : movingTime // ignore: cast_nullable_to_non_nullable
as int,elapsedTime: null == elapsedTime ? _self.elapsedTime : elapsedTime // ignore: cast_nullable_to_non_nullable
as int,totalElevationGain: null == totalElevationGain ? _self.totalElevationGain : totalElevationGain // ignore: cast_nullable_to_non_nullable
as double,startDate: null == startDate ? _self.startDate : startDate // ignore: cast_nullable_to_non_nullable
as String,averageSpeed: null == averageSpeed ? _self.averageSpeed : averageSpeed // ignore: cast_nullable_to_non_nullable
as double,maxSpeed: null == maxSpeed ? _self.maxSpeed : maxSpeed // ignore: cast_nullable_to_non_nullable
as double,averageHeartrate: freezed == averageHeartrate ? _self.averageHeartrate : averageHeartrate // ignore: cast_nullable_to_non_nullable
as double?,maxHeartrate: freezed == maxHeartrate ? _self.maxHeartrate : maxHeartrate // ignore: cast_nullable_to_non_nullable
as double?,averageCadence: freezed == averageCadence ? _self.averageCadence : averageCadence // ignore: cast_nullable_to_non_nullable
as double?,sufferScore: freezed == sufferScore ? _self.sufferScore : sufferScore // ignore: cast_nullable_to_non_nullable
as int?,hasHeartrate: null == hasHeartrate ? _self.hasHeartrate : hasHeartrate // ignore: cast_nullable_to_non_nullable
as bool,workoutType: freezed == workoutType ? _self.workoutType : workoutType // ignore: cast_nullable_to_non_nullable
as int?,perceivedExertion: freezed == perceivedExertion ? _self.perceivedExertion : perceivedExertion // ignore: cast_nullable_to_non_nullable
as double?,shoeId: freezed == shoeId ? _self.shoeId : shoeId // ignore: cast_nullable_to_non_nullable
as String?,shoeAssignmentModifiedAt: freezed == shoeAssignmentModifiedAt ? _self.shoeAssignmentModifiedAt : shoeAssignmentModifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [ActivityModel].
extension ActivityModelPatterns on ActivityModel {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ActivityModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ActivityModel() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ActivityModel value)  $default,){
final _that = this;
switch (_that) {
case _ActivityModel():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ActivityModel value)?  $default,){
final _that = this;
switch (_that) {
case _ActivityModel() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String name,  String type,  double distance,  int movingTime,  int elapsedTime,  double totalElevationGain,  String startDate,  double averageSpeed,  double maxSpeed,  double? averageHeartrate,  double? maxHeartrate,  double? averageCadence,  int? sufferScore,  bool hasHeartrate,  int? workoutType,  double? perceivedExertion,  String? shoeId,  DateTime? shoeAssignmentModifiedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ActivityModel() when $default != null:
return $default(_that.id,_that.name,_that.type,_that.distance,_that.movingTime,_that.elapsedTime,_that.totalElevationGain,_that.startDate,_that.averageSpeed,_that.maxSpeed,_that.averageHeartrate,_that.maxHeartrate,_that.averageCadence,_that.sufferScore,_that.hasHeartrate,_that.workoutType,_that.perceivedExertion,_that.shoeId,_that.shoeAssignmentModifiedAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String name,  String type,  double distance,  int movingTime,  int elapsedTime,  double totalElevationGain,  String startDate,  double averageSpeed,  double maxSpeed,  double? averageHeartrate,  double? maxHeartrate,  double? averageCadence,  int? sufferScore,  bool hasHeartrate,  int? workoutType,  double? perceivedExertion,  String? shoeId,  DateTime? shoeAssignmentModifiedAt)  $default,) {final _that = this;
switch (_that) {
case _ActivityModel():
return $default(_that.id,_that.name,_that.type,_that.distance,_that.movingTime,_that.elapsedTime,_that.totalElevationGain,_that.startDate,_that.averageSpeed,_that.maxSpeed,_that.averageHeartrate,_that.maxHeartrate,_that.averageCadence,_that.sufferScore,_that.hasHeartrate,_that.workoutType,_that.perceivedExertion,_that.shoeId,_that.shoeAssignmentModifiedAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String name,  String type,  double distance,  int movingTime,  int elapsedTime,  double totalElevationGain,  String startDate,  double averageSpeed,  double maxSpeed,  double? averageHeartrate,  double? maxHeartrate,  double? averageCadence,  int? sufferScore,  bool hasHeartrate,  int? workoutType,  double? perceivedExertion,  String? shoeId,  DateTime? shoeAssignmentModifiedAt)?  $default,) {final _that = this;
switch (_that) {
case _ActivityModel() when $default != null:
return $default(_that.id,_that.name,_that.type,_that.distance,_that.movingTime,_that.elapsedTime,_that.totalElevationGain,_that.startDate,_that.averageSpeed,_that.maxSpeed,_that.averageHeartrate,_that.maxHeartrate,_that.averageCadence,_that.sufferScore,_that.hasHeartrate,_that.workoutType,_that.perceivedExertion,_that.shoeId,_that.shoeAssignmentModifiedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ActivityModel extends ActivityModel {
  const _ActivityModel({required this.id, required this.name, required this.type, required this.distance, required this.movingTime, required this.elapsedTime, required this.totalElevationGain, required this.startDate, required this.averageSpeed, required this.maxSpeed, this.averageHeartrate, this.maxHeartrate, this.averageCadence, this.sufferScore, this.hasHeartrate = false, this.workoutType, this.perceivedExertion, this.shoeId, this.shoeAssignmentModifiedAt}): super._();
  factory _ActivityModel.fromJson(Map<String, dynamic> json) => _$ActivityModelFromJson(json);

@override final  int id;
@override final  String name;
@override final  String type;
@override final  double distance;
@override final  int movingTime;
@override final  int elapsedTime;
@override final  double totalElevationGain;
@override final  String startDate;
@override final  double averageSpeed;
@override final  double maxSpeed;
@override final  double? averageHeartrate;
@override final  double? maxHeartrate;
@override final  double? averageCadence;
@override final  int? sufferScore;
@override@JsonKey() final  bool hasHeartrate;
@override final  int? workoutType;
@override final  double? perceivedExertion;
@override final  String? shoeId;
@override final  DateTime? shoeAssignmentModifiedAt;

/// Create a copy of ActivityModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ActivityModelCopyWith<_ActivityModel> get copyWith => __$ActivityModelCopyWithImpl<_ActivityModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ActivityModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ActivityModel&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.distance, distance) || other.distance == distance)&&(identical(other.movingTime, movingTime) || other.movingTime == movingTime)&&(identical(other.elapsedTime, elapsedTime) || other.elapsedTime == elapsedTime)&&(identical(other.totalElevationGain, totalElevationGain) || other.totalElevationGain == totalElevationGain)&&(identical(other.startDate, startDate) || other.startDate == startDate)&&(identical(other.averageSpeed, averageSpeed) || other.averageSpeed == averageSpeed)&&(identical(other.maxSpeed, maxSpeed) || other.maxSpeed == maxSpeed)&&(identical(other.averageHeartrate, averageHeartrate) || other.averageHeartrate == averageHeartrate)&&(identical(other.maxHeartrate, maxHeartrate) || other.maxHeartrate == maxHeartrate)&&(identical(other.averageCadence, averageCadence) || other.averageCadence == averageCadence)&&(identical(other.sufferScore, sufferScore) || other.sufferScore == sufferScore)&&(identical(other.hasHeartrate, hasHeartrate) || other.hasHeartrate == hasHeartrate)&&(identical(other.workoutType, workoutType) || other.workoutType == workoutType)&&(identical(other.perceivedExertion, perceivedExertion) || other.perceivedExertion == perceivedExertion)&&(identical(other.shoeId, shoeId) || other.shoeId == shoeId)&&(identical(other.shoeAssignmentModifiedAt, shoeAssignmentModifiedAt) || other.shoeAssignmentModifiedAt == shoeAssignmentModifiedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,name,type,distance,movingTime,elapsedTime,totalElevationGain,startDate,averageSpeed,maxSpeed,averageHeartrate,maxHeartrate,averageCadence,sufferScore,hasHeartrate,workoutType,perceivedExertion,shoeId,shoeAssignmentModifiedAt]);

@override
String toString() {
  return 'ActivityModel(id: $id, name: $name, type: $type, distance: $distance, movingTime: $movingTime, elapsedTime: $elapsedTime, totalElevationGain: $totalElevationGain, startDate: $startDate, averageSpeed: $averageSpeed, maxSpeed: $maxSpeed, averageHeartrate: $averageHeartrate, maxHeartrate: $maxHeartrate, averageCadence: $averageCadence, sufferScore: $sufferScore, hasHeartrate: $hasHeartrate, workoutType: $workoutType, perceivedExertion: $perceivedExertion, shoeId: $shoeId, shoeAssignmentModifiedAt: $shoeAssignmentModifiedAt)';
}


}

/// @nodoc
abstract mixin class _$ActivityModelCopyWith<$Res> implements $ActivityModelCopyWith<$Res> {
  factory _$ActivityModelCopyWith(_ActivityModel value, $Res Function(_ActivityModel) _then) = __$ActivityModelCopyWithImpl;
@override @useResult
$Res call({
 int id, String name, String type, double distance, int movingTime, int elapsedTime, double totalElevationGain, String startDate, double averageSpeed, double maxSpeed, double? averageHeartrate, double? maxHeartrate, double? averageCadence, int? sufferScore, bool hasHeartrate, int? workoutType, double? perceivedExertion, String? shoeId, DateTime? shoeAssignmentModifiedAt
});




}
/// @nodoc
class __$ActivityModelCopyWithImpl<$Res>
    implements _$ActivityModelCopyWith<$Res> {
  __$ActivityModelCopyWithImpl(this._self, this._then);

  final _ActivityModel _self;
  final $Res Function(_ActivityModel) _then;

/// Create a copy of ActivityModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? type = null,Object? distance = null,Object? movingTime = null,Object? elapsedTime = null,Object? totalElevationGain = null,Object? startDate = null,Object? averageSpeed = null,Object? maxSpeed = null,Object? averageHeartrate = freezed,Object? maxHeartrate = freezed,Object? averageCadence = freezed,Object? sufferScore = freezed,Object? hasHeartrate = null,Object? workoutType = freezed,Object? perceivedExertion = freezed,Object? shoeId = freezed,Object? shoeAssignmentModifiedAt = freezed,}) {
  return _then(_ActivityModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,distance: null == distance ? _self.distance : distance // ignore: cast_nullable_to_non_nullable
as double,movingTime: null == movingTime ? _self.movingTime : movingTime // ignore: cast_nullable_to_non_nullable
as int,elapsedTime: null == elapsedTime ? _self.elapsedTime : elapsedTime // ignore: cast_nullable_to_non_nullable
as int,totalElevationGain: null == totalElevationGain ? _self.totalElevationGain : totalElevationGain // ignore: cast_nullable_to_non_nullable
as double,startDate: null == startDate ? _self.startDate : startDate // ignore: cast_nullable_to_non_nullable
as String,averageSpeed: null == averageSpeed ? _self.averageSpeed : averageSpeed // ignore: cast_nullable_to_non_nullable
as double,maxSpeed: null == maxSpeed ? _self.maxSpeed : maxSpeed // ignore: cast_nullable_to_non_nullable
as double,averageHeartrate: freezed == averageHeartrate ? _self.averageHeartrate : averageHeartrate // ignore: cast_nullable_to_non_nullable
as double?,maxHeartrate: freezed == maxHeartrate ? _self.maxHeartrate : maxHeartrate // ignore: cast_nullable_to_non_nullable
as double?,averageCadence: freezed == averageCadence ? _self.averageCadence : averageCadence // ignore: cast_nullable_to_non_nullable
as double?,sufferScore: freezed == sufferScore ? _self.sufferScore : sufferScore // ignore: cast_nullable_to_non_nullable
as int?,hasHeartrate: null == hasHeartrate ? _self.hasHeartrate : hasHeartrate // ignore: cast_nullable_to_non_nullable
as bool,workoutType: freezed == workoutType ? _self.workoutType : workoutType // ignore: cast_nullable_to_non_nullable
as int?,perceivedExertion: freezed == perceivedExertion ? _self.perceivedExertion : perceivedExertion // ignore: cast_nullable_to_non_nullable
as double?,shoeId: freezed == shoeId ? _self.shoeId : shoeId // ignore: cast_nullable_to_non_nullable
as String?,shoeAssignmentModifiedAt: freezed == shoeAssignmentModifiedAt ? _self.shoeAssignmentModifiedAt : shoeAssignmentModifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
