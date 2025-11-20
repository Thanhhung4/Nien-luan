import 'package:pocketbase/pocketbase.dart';
import 'package:myshop/models/ingredient.dart';
import 'package:myshop/models/ingredient_batch.dart';
import 'package:myshop/models/menu_item_ingredient.dart';
import 'package:myshop/models/order_item_view.dart';

class InventoryService {
  final PocketBase pb;

  InventoryService(this.pb);

  // ============================================
  // 1. QUẢN LÝ NGUYÊN VẬT LIỆU CƠ BẢN
  // ============================================

  Future<List<Ingredient>> getIngredients() async {
    try {
      final records = await pb
          .collection('ingredients')
          .getFullList(sort: 'name');
      return records.map((r) => Ingredient.fromRecord(r)).toList();
    } catch (e) {
      print('InventoryService - getIngredients Error: $e');
      throw Exception('Lỗi tải nguyên vật liệu: $e');
    }
  }

  Future<void> createIngredient({
    required String name,
    required String unit,
    required double costPerUnit,
    required double stockQuantity,
  }) async {
    await pb
        .collection('ingredients')
        .create(
          body: {
            'name': name,
            'unit': unit,
            'cost_per_unit': costPerUnit,
            'stock_quantity': stockQuantity,
          },
        );
  }

  Future<void> updateIngredient({
    required String id,
    required String name,
    required String unit,
    required double costPerUnit,
    required double stockQuantity,
  }) async {
    await pb
        .collection('ingredients')
        .update(
          id,
          body: {
            'name': name,
            'unit': unit,
            'cost_per_unit': costPerUnit,
            'stock_quantity': stockQuantity,
          },
        );
  }

  Future<void> deleteIngredient(String id) async {
    await pb.collection('ingredients').delete(id);
  }

  // ============================================
  // 2. QUẢN LÝ LÔ HÀNG (BATCHES)
  // ============================================

  Future<List<IngredientBatch>> getBatchesForIngredient(
    String ingredientId,
  ) async {
    try {
      final records = await pb
          .collection('ingredient_batches')
          .getFullList(
            filter: 'ingredient = "$ingredientId" && quantity > 0',
            sort: 'import_date',
          );
      return records.map((r) => IngredientBatch.fromRecord(r)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> importBatch({
    required String ingredientId,
    required double quantity,
    required DateTime importDate,
    required DateTime expiryDate,
  }) async {
    // 1. Tạo lô hàng mới
    await pb
        .collection('ingredient_batches')
        .create(
          body: {
            'ingredient': ingredientId,
            'quantity': quantity,
            'initial_quantity': quantity,
            'import_date': importDate.toUtc().toIso8601String(),
            'expiry_date': expiryDate.toUtc().toIso8601String(),
          },
        );

    // 2. Cộng vào tổng tồn kho
    await pb
        .collection('ingredients')
        .update(ingredientId, body: {'stock_quantity+': quantity});

    // 3. Kiểm tra lại thực đơn (Có thể món hết hàng giờ đã có lại)
    await checkAndUpdateMenuAvailability([ingredientId]);
  }

  Future<void> disposeBatch({
    required String batchId,
    required String ingredientId,
    required String ingredientName,
    required double quantity,
    required double costPerUnit,
  }) async {
    try {
      final totalLoss = quantity * costPerUnit;
      await pb
          .collection('spoilage_logs')
          .create(
            body: {
              'ingredient_name': ingredientName,
              'quantity': quantity,
              'total_loss': totalLoss,
            },
          );

      await pb.collection('ingredient_batches').delete(batchId);

      await pb
          .collection('ingredients')
          .update(ingredientId, body: {'stock_quantity-': quantity});

      // Kiểm tra lại thực đơn (Có thể món sẽ bị hết hàng)
      await checkAndUpdateMenuAvailability([ingredientId]);

      print('Đã tiêu hủy $quantity $ingredientName. Hao hụt: $totalLoss');
    } catch (e) {
      print('Lỗi tiêu hủy: $e');
      throw Exception('Không thể tiêu hủy lô hàng: $e');
    }
  }

  Future<void> deleteBatch(
    String batchId,
    String ingredientId,
    double quantity,
  ) async {
    await pb.collection('ingredient_batches').delete(batchId);
    await pb
        .collection('ingredients')
        .update(ingredientId, body: {'stock_quantity-': quantity});
    await checkAndUpdateMenuAvailability([ingredientId]);
  }

  // ============================================
  // 3. TRỪ KHO TỰ ĐỘNG (FIFO)
  // ============================================

  Future<void> deductStockForOrder(List<OrderItemView> itemsInOrder) async {
    print('Bắt đầu trừ kho FIFO...');
    final Map<String, double> totalNeededMap = {};

    final menuItemIdFilter =
        '(${itemsInOrder.map((item) => "menu_item.id = '${item.menuItem.id}'").join(' || ')})';
    if (menuItemIdFilter == '()') return;

    final allRecipes = await pb
        .collection('menu_item_ingredients')
        .getFullList(filter: menuItemIdFilter);

    for (final itemInOrder in itemsInOrder) {
      final recipes = allRecipes.where(
        (r) => r.getStringValue('menu_item') == itemInOrder.menuItem.id,
      );
      for (final recipe in recipes) {
        final ingId = recipe.getStringValue('ingredient');
        final qty = recipe.getDoubleValue('quantity_needed');
        totalNeededMap[ingId] =
            (totalNeededMap[ingId] ?? 0) + (qty * itemInOrder.quantity);
      }
    }

    for (final entry in totalNeededMap.entries) {
      String ingredientId = entry.key;
      double amountNeeded = entry.value;

      final batches = await getBatchesForIngredient(ingredientId);

      for (final batch in batches) {
        if (amountNeeded <= 0) break;

        double deductAmount = 0;
        if (batch.quantity >= amountNeeded) {
          deductAmount = amountNeeded;
          amountNeeded = 0;
        } else {
          deductAmount = batch.quantity;
          amountNeeded -= batch.quantity;
        }

        await pb
            .collection('ingredient_batches')
            .update(batch.id, body: {'quantity-': deductAmount});
      }

      await pb
          .collection('ingredients')
          .update(ingredientId, body: {'stock_quantity-': entry.value});
    }

    // 4. Tự động cập nhật trạng thái món ăn
    final changedIds = totalNeededMap.keys.toList();
    await checkAndUpdateMenuAvailability(changedIds);

    print('Trừ kho hoàn tất.');
  }

  // ============================================
  // 4. TỰ ĐỘNG CẬP NHẬT TRẠNG THÁI MÓN ĂN (LOGIC MỚI)
  // ============================================

  Future<void> checkAndUpdateMenuAvailability(
    List<String> ingredientIds,
  ) async {
    if (ingredientIds.isEmpty) return;

    print('Checking menu availability for ingredients: $ingredientIds');

    // 1. Tìm các món ăn bị ảnh hưởng
    final filter = ingredientIds.map((id) => 'ingredient = "$id"').join(' || ');
    final relatedRecipes = await pb
        .collection('menu_item_ingredients')
        .getFullList(filter: filter);
    final affectedMenuItemIds = relatedRecipes
        .map((r) => r.getStringValue('menu_item'))
        .toSet();

    // 2. Kiểm tra từng món
    for (final menuItemId in affectedMenuItemIds) {
      try {
        final ingredientsNeeded = await pb
            .collection('menu_item_ingredients')
            .getFullList(
              filter: 'menu_item = "$menuItemId"',
              expand: 'ingredient',
            );

        bool isEnough = true;
        for (final item in ingredientsNeeded) {
          final requiredQty = item.getDoubleValue('quantity_needed');
          final ingredientRecord = item.expand['ingredient']?.first;

          if (ingredientRecord != null) {
            final currentStock = ingredientRecord.getDoubleValue(
              'stock_quantity',
            );
            // Nếu kho < công thức yêu cầu -> Hết hàng
            if (currentStock < requiredQty) {
              isEnough = false;
              break;
            }
          }
        }

        // Cập nhật in_stock
        await pb
            .collection('menu_items')
            .update(menuItemId, body: {'in_stock': isEnough});
        print('Updated menu item $menuItemId in_stock = $isEnough');
      } catch (e) {
        print('Error checking stock for menu item $menuItemId: $e');
      }
    }
  }

  // ============================================
  // 5. ĐỒNG BỘ KHO & CÔNG THỨC
  // ============================================
  Future<void> recalibrateAllStock() async {
    print("Đang đồng bộ kho...");
    final ingredients = await getIngredients();
    for (final ing in ingredients) {
      final batches = await getBatchesForIngredient(ing.id);
      double realStock = 0;
      for (var b in batches) {
        realStock += b.quantity;
      }
      if ((ing.stockQuantity - realStock).abs() > 0.001) {
        await pb
            .collection('ingredients')
            .update(ing.id, body: {'stock_quantity': realStock});
      }
    }
    if (ingredients.isNotEmpty) {
      await checkAndUpdateMenuAvailability(
        ingredients.map((e) => e.id).toList(),
      );
    }
    print("Đồng bộ xong.");
  }

  // ============================================
  // 6. QUẢN LÝ CÔNG THỨC (Giữ nguyên)
  // ============================================
  Future<List<MenuItemIngredient>> getIngredientsForMenuItem(
    String menuItemId,
  ) async {
    try {
      final records = await pb
          .collection('menu_item_ingredients')
          .getFullList(
            filter: 'menu_item = "$menuItemId"',
            expand: 'ingredient',
          );
      return records.map((r) => MenuItemIngredient.fromRecord(r)).toList();
    } catch (e) {
      throw Exception('Lỗi tải công thức: $e');
    }
  }

  Future<void> createMenuItemIngredient({
    required String menuItemId,
    required String ingredientId,
    required double quantityNeeded,
  }) async {
    await pb
        .collection('menu_item_ingredients')
        .create(
          body: {
            'menu_item': menuItemId,
            'ingredient': ingredientId,
            'quantity_needed': quantityNeeded,
          },
        );
  }

  Future<void> deleteMenuItemIngredient(String recipeItemId) async {
    await pb.collection('menu_item_ingredients').delete(recipeItemId);
  }

  Future<void> updateMenuItemIngredient({
    required String recipeItemId,
    required double quantityNeeded,
  }) async {
    await pb
        .collection('menu_item_ingredients')
        .update(recipeItemId, body: {'quantity_needed': quantityNeeded});
  }
}
