import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/local_equipment_datasource.dart';
import '../../domain/entities/shoe_equipment.dart';

final equipmentProvider = FutureProvider<List<ShoeEquipment>>((ref) async {
  return LocalEquipmentDataSource().getAll();
});
