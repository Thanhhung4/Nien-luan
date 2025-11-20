// [TẠO FILE MỚI: lib/models/ingredient.dart]

import 'package:pocketbase/pocketbase.dart';

class Ingredient {
  final String id;
  final String name;
  final String unit;
  final double stockQuantity;
  final double costPerUnit;

  Ingredient({
    required this.id,
    required this.name,
    required this.unit,
    required this.stockQuantity,
    required this.costPerUnit,
  });

  factory Ingredient.fromRecord(RecordModel record) {
    return Ingredient(
      id: record.id,
      name: record.getStringValue('name'),
      unit: record.getStringValue('unit'),
      stockQuantity: record.getDoubleValue('stock_quantity'),
      costPerUnit: record.getDoubleValue('cost_per_unit'),
    );
  }
}
