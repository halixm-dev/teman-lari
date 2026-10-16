import 'package:json_annotation/json_annotation.dart';

part 'shoe_equipment.g.dart';

@JsonEnum(fieldRename: FieldRename.snake)
enum ShoeCategory {
  dailyTrainer,
  maxCushionRecovery,
  tempoWorkout,
  raceDayPlated,
}

@JsonEnum(fieldRename: FieldRename.snake)
enum FoamChemistry { supercriticalPebaTpu, traditionalEva }

/// A durable pair of shoes. Creation time is immutable when known.
@JsonSerializable(fieldRename: FieldRename.snake)
class ShoeEquipment {
  final String id;
  final String name;
  final ShoeCategory category;
  final FoamChemistry? foamChemistry;
  final double? lifecycleTargetMeters;
  final double? performanceTargetMeters;
  final DateTime? createdAt;
  final DateTime? modifiedAt;

  const ShoeEquipment({
    required this.id,
    required this.name,
    required this.category,
    this.foamChemistry,
    this.lifecycleTargetMeters,
    this.performanceTargetMeters,
    this.createdAt,
    this.modifiedAt,
  });

  factory ShoeEquipment.fromJson(Map<String, dynamic> json) {
    validateShoeInstant(json['created_at']);
    validateShoeInstant(json['modified_at']);
    final record = _$ShoeEquipmentFromJson(json);
    record.validate();
    return record;
  }

  Map<String, dynamic> toJson() => _$ShoeEquipmentToJson(this);

  void validate() {
    if (id.trim().isEmpty || name.trim().isEmpty) {
      throw FormatException('Shoe identity and name must be nonempty.');
    }
    for (final target in [lifecycleTargetMeters, performanceTargetMeters]) {
      if (target != null && (!target.isFinite || target <= 0)) {
        throw FormatException('Shoe target must be positive and finite.');
      }
    }
  }

  ShoeEquipment edited(DateTime instant, {DateTime? originalCreation}) =>
      ShoeEquipment(
        id: id,
        name: name,
        category: category,
        foamChemistry: foamChemistry,
        lifecycleTargetMeters: lifecycleTargetMeters,
        performanceTargetMeters: performanceTargetMeters,
        createdAt: originalCreation?.toUtc(),
        modifiedAt: instant.toUtc(),
      );
}

void validateShoeInstant(Object? value) {
  if (value == null) return;
  if (value is! String) throw FormatException('Invalid shoe timestamp.');
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,6})?(Z|[+-]\d{2}:\d{2})$',
  ).firstMatch(value);
  if (match == null) {
    throw FormatException('Timestamp needs an explicit timezone.');
  }
  final parts = [for (var i = 1; i <= 6; i++) int.parse(match.group(i) ?? '')];
  final civil = DateTime.utc(
    parts[0],
    parts[1],
    parts[2],
    parts[3],
    parts[4],
    parts[5],
  );
  final actual = [
    civil.year,
    civil.month,
    civil.day,
    civil.hour,
    civil.minute,
    civil.second,
  ];
  if (List.generate(6, (i) => parts[i] != actual[i]).any((bad) => bad)) {
    throw FormatException('Invalid timestamp calendar or clock.');
  }
  final zone = match.group(7) ?? '';
  if (zone != 'Z' &&
      (int.parse(zone.substring(1, 3)) > 23 ||
          int.parse(zone.substring(4)) > 59)) {
    throw FormatException('Invalid timestamp timezone.');
  }
}
