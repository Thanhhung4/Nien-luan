// [TẠO FILE MỚI: lib/models/menu_item_ingredient.dart]

import 'package:pocketbase/pocketbase.dart';
import 'package:myshop/models/ingredient.dart';

// Model này chứa công thức, ví dụ: 1 "Phở Bò" cần 0.1 "kg" "Bò"
class MenuItemIngredient {
  final String id;
  final String menuItemId;
  final double quantityNeeded;
  final Ingredient ingredient; // Thông tin nguyên liệu (đã expand)

  MenuItemIngredient({
    required this.id,
    required this.menuItemId,
    required this.quantityNeeded,
    required this.ingredient,
  });

  // Tính giá vốn của thành phần này
  double get cost => ingredient.costPerUnit * quantityNeeded;

  factory MenuItemIngredient.fromRecord(RecordModel record) {
    // Phải expand 'ingredient' khi gọi hàm này
    final ingredientRecord = record.expand['ingredient']!.first;

    return MenuItemIngredient(
      id: record.id,
      menuItemId: record.getStringValue('menu_item'),
      quantityNeeded: record.getDoubleValue('quantity_needed'),
      ingredient: Ingredient.fromRecord(ingredientRecord),
    );
  }
}
