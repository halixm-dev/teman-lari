import 'package:flutter/foundation.dart';
import '../../../domain/entities/shoe_equipment.dart';
import 'training_plan_validation.dart';

typedef ArchiveRule = void Function(Object? value);

Map<String, dynamic> archiveObject(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw FormatException('Expected an archive object.');
  }
  return value;
}

Map<String, dynamic> archiveShape(
  Object? value,
  Map<String, ArchiveRule> rules,
) {
  final object = archiveObject(value);
  for (final entry in rules.entries) {
    if (!object.containsKey(entry.key)) {
      throw FormatException('Missing required field: ${entry.key}.');
    }
    entry.value(object[entry.key]);
  }
  return object;
}

void archiveString(Object? value) {
  if (value is! String) throw FormatException('Expected archive text.');
}

void archiveNonempty(Object? value) {
  archiveString(value);
  if ((value as String).trim().isEmpty) {
    throw FormatException('An archive identity or name is empty.');
  }
}

void archiveNumber(Object? value) {
  if (value is! num || !value.isFinite) {
    throw FormatException('Expected a finite measurement.');
  }
}

void archiveInteger(Object? value) {
  if (value is! int || value < -9007199254740991 || value > 9007199254740991) {
    throw FormatException('Expected an exactly representable integer.');
  }
}

void archiveNonnegativeInteger(Object? value) {
  archiveInteger(value);
  if ((value as int) < 0) throw FormatException('Negative integer.');
}

void archiveNonnegative(Object? value) {
  archiveNumber(value);
  if ((value as num) < 0) throw FormatException('Negative measurement.');
}

void archiveBool(Object? value) {
  if (value is! bool) throw FormatException('Expected archive boolean.');
}

ArchiveRule archiveNullable(ArchiveRule rule) => (value) {
  if (value != null) rule(value);
};

ArchiveRule archiveList(ArchiveRule rule) => (value) {
  if (value is! List) throw FormatException('Expected an archive collection.');
  for (final item in value) {
    rule(item);
  }
};

void archiveInstant(Object? value) {
  archiveString(value);
  validateShoeInstant(value);
  final parsed = DateTime.tryParse(value as String);
  if (parsed == null) throw FormatException('Invalid archive instant.');
}

void archiveDate(Object? value) {
  archiveString(value);
  const PlanDateConverter().fromJson(value as String);
}

void archiveDuration(Object? value) {
  archiveNumber(value);
  const PlanDurationConverter().fromJson(value as num);
}

void archiveIdentity(Object? value) {
  archiveString(value);
  final text = value as String;
  if (!RegExp(r'^(?:0|-[1-9][0-9]*|[1-9][0-9]*)$').hasMatch(text)) {
    throw FormatException('Activity identity must be canonical decimal text.');
  }
  final id = BigInt.parse(text);
  final maximum = BigInt.parse(
    kIsWeb ? '9007199254740991' : '9223372036854775807',
  );
  final minimum = kIsWeb ? -maximum : -maximum - BigInt.one;
  if (id < minimum || id > maximum) {
    throw FormatException('Activity identity cannot be represented exactly.');
  }
}

void archivePreference(Object? value, ArchiveRule rule) {
  archiveShape(value, {
    'value': archiveNullable(rule),
    'modified_at': archiveNullable(archiveInstant),
  });
}

void archiveUnique(List<dynamic> rows, String key) {
  final identities = <Object?>{};
  for (final row in rows) {
    if (!identities.add(archiveObject(row)[key])) {
      throw FormatException('Repeated archive identity: $key.');
    }
  }
}
