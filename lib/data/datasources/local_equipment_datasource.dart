import 'package:hive_flutter/hive_flutter.dart';

import '../../domain/entities/shoe_equipment.dart';
import '../backup/local_data_coordinator.dart';

class LocalEquipmentDataSource {
  final LocalDataCoordinator coordinator;
  final DateTime Function() clock;

  LocalEquipmentDataSource({
    LocalDataCoordinator? coordinator,
    DateTime Function()? clock,
  }) : coordinator = coordinator ?? LocalDataCoordinator.shared,
       clock = clock ?? DateTime.now;

  Future<Box> get _box async => Hive.isBoxOpen('equipment')
      ? Hive.box('equipment')
      : await Hive.openBox('equipment');

  Future<List<ShoeEquipment>> getAll() => coordinator.read(() async {
    final box = await _box;
    return box.keys.map((key) => _decode(key, box.get(key))).toList();
  });

  Future<void> save(ShoeEquipment shoe) => coordinator.write(() async {
    shoe.validate();
    final box = await _box;
    final old = box.get(shoe.id);
    final existing = old == null ? null : _decode(shoe.id, old);
    if (existing?.createdAt != null &&
        shoe.createdAt != null &&
        existing?.createdAt != shoe.createdAt) {
      throw StateError('Shoe ID belongs to another pair.');
    }
    final created = existing == null
        ? (shoe.createdAt ?? clock().toUtc())
        : existing.createdAt;
    await box.put(
      shoe.id,
      shoe.edited(clock(), originalCreation: created).toJson(),
    );
    await box.flush();
  });

  ShoeEquipment _decode(Object? key, Object? raw) {
    final record = ShoeEquipment.fromJson(
      Map<String, dynamic>.from(raw as Map),
    );
    if (record.id != key) {
      throw StateError('Stored shoe identity is inconsistent.');
    }
    return record;
  }
}
