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

  Future<bool> _canReadRecord(String collection, String recordId) async {
    try {
      await pb.collection(collection).getOne(recordId);
      return true;
    } on ClientException catch (e) {
      if (e.statusCode == 404) return false;
      rethrow;
    }
  }

  bool _looksLikePocketBaseId(String value) {
    return RegExp(r'^[a-z0-9]{15}$', caseSensitive: false).hasMatch(value);
  }

  Future<void> deductStockForOrder(List<OrderItemView> itemsInOrder) async {
    print('Bắt đầu trừ kho FIFO...');
    final Map<String, double> totalNeededMap = {};

    final validMenuItemIds = itemsInOrder
        .map((item) => item.menuItem.id.trim())
        .where((id) => _looksLikePocketBaseId(id))
        .toSet()
        .toList();

    if (validMenuItemIds.isEmpty) {
      print(
        'Không có menu_item hợp lệ để trừ kho (món đã bị xóa hoặc id không hợp lệ).',
      );
      return;
    }

    // Filter theo relation id (PocketBase): menu_item = "<id>"
    final menuItemIdFilter =
        '(${validMenuItemIds.map((id) => "menu_item = \"$id\"").join(' || ')})';

    final allRecipes = await pb
        .collection('menu_item_ingredients')
        .getFullList(filter: menuItemIdFilter);

    for (final itemInOrder in itemsInOrder) {
      final menuItemId = itemInOrder.menuItem.id.trim();
      if (!_looksLikePocketBaseId(menuItemId)) {
        // Skip deleted/invalid menu item entries
        continue;
      }
      final recipes = allRecipes.where(
        (r) => r.getStringValue('menu_item') == menuItemId,
      );
      for (final recipe in recipes) {
        final ingId = recipe.getStringValue('ingredient').trim();
        if (!_looksLikePocketBaseId(ingId)) {
          // Ingredient relation missing/deleted -> avoid 404 updates
          print(
            'Bỏ qua công thức thiếu nguyên liệu: menu_item=$menuItemId ingredient="$ingId"',
          );
          continue;
        }
        final qty = recipe.getDoubleValue('quantity_needed');
        totalNeededMap[ingId] =
            (totalNeededMap[ingId] ?? 0) + (qty * itemInOrder.quantity);
      }
    }

    if (totalNeededMap.isEmpty) {
      print(
        'Không có nguyên liệu nào cần trừ (công thức trống hoặc thiếu liên kết).',
      );
      return;
    }

    // PRE-CHECK:
    // - Luôn đảm bảo `ingredients.stock_quantity` đủ.
    // - Nếu có batches (FIFO) thì tổng batch phải đủ.
    // - Nếu KHÔNG có batch nào thì vẫn cho phép trừ trực tiếp trên `ingredients.stock_quantity`.
    final ingredientIds = totalNeededMap.keys.toList();
    final ingredientFilter =
        '(${ingredientIds.map((id) => 'id = "$id"').join(' || ')})';
    final ingredientRecords = await pb
        .collection('ingredients')
        .getFullList(filter: ingredientFilter);
    final Map<String, double> stockById = {
      for (final r in ingredientRecords)
        r.id: r.getDoubleValue('stock_quantity'),
    };
    final Map<String, String> nameById = {
      for (final r in ingredientRecords) r.id: r.getStringValue('name'),
    };

    final List<String> insufficient = [];
    final Map<String, List<IngredientBatch>> batchesByIngredientId = {};

    for (final entry in totalNeededMap.entries) {
      final ingredientId = entry.key;
      final needed = entry.value;
      final name = (nameById[ingredientId] ?? '').trim();
      final label = name.isNotEmpty ? '$name (id=$ingredientId)' : ingredientId;

      final stock = stockById[ingredientId];
      if (stock == null) {
        insufficient.add('Nguyên liệu không tồn tại: $label');
        continue;
      }
      if (stock + 1e-9 < needed) {
        insufficient.add('Thiếu nguyên liệu ($label): cần $needed, còn $stock');
        continue;
      }

      final batches = await getBatchesForIngredient(ingredientId);
      batchesByIngredientId[ingredientId] = batches;
      if (batches.isNotEmpty) {
        final batchSum = batches.fold<double>(0.0, (s, b) => s + b.quantity);
        if (batchSum + 1e-9 < needed) {
          insufficient.add(
            'Thiếu lô FIFO ($label): cần $needed, tổng lô còn $batchSum (stock=$stock)',
          );
        }
      }
    }

    if (insufficient.isNotEmpty) {
      throw Exception(
        'Không đủ nguyên liệu để thanh toán:\n\n${insufficient.join('\n')}',
      );
    }

    for (final entry in totalNeededMap.entries) {
      String ingredientId = entry.key;
      double amountNeeded = entry.value;

      final batches =
          batchesByIngredientId[ingredientId] ??
          await getBatchesForIngredient(ingredientId);

      for (final batch in batches) {
        if (amountNeeded <= 0) break;

        final double deductAmount = batch.quantity >= amountNeeded
            ? amountNeeded
            : batch.quantity;

        try {
          await pb
              .collection('ingredient_batches')
              .update(batch.id, body: {'quantity-': deductAmount});

          amountNeeded -= deductAmount;
        } on ClientException catch (e) {
          if (e.statusCode == 404) {
            // PocketBase often returns 404 when update is denied by rules.
            // If batches can't be updated, fall back to decrementing only
            // `ingredients.stock_quantity` so checkout can still proceed.
            final canRead = await _canReadRecord(
              'ingredient_batches',
              batch.id,
            );
            if (canRead) {
              print(
                'Warning: Không thể update ingredient_batches (batchId=${batch.id}) do PocketBase rules. '
                'Bỏ qua FIFO batches và chỉ trừ ingredients.stock_quantity cho ingredientId=$ingredientId.',
              );
              // Stop trying to update FIFO batches for this ingredient.
              amountNeeded = 0;
              break;
            }

            // Batch record might have been deleted or is not readable.
            // Skip this batch and continue best-effort.
            print(
              'Warning: ingredient_batches batchId=${batch.id} không tồn tại hoặc không đọc được (404). '
              'Bỏ qua batch này và tiếp tục trừ theo ingredients.stock_quantity.',
            );
            continue;
          }
          rethrow;
        }
      }

      try {
        await pb
            .collection('ingredients')
            .update(ingredientId, body: {'stock_quantity-': entry.value});
      } on ClientException catch (e) {
        if (e.statusCode == 404) {
          throw Exception(
            'PocketBase 404 khi trừ kho (ingredients:update $ingredientId).\n'
            'Nguyên nhân thường gặp: nguyên liệu không tồn tại hoặc user hiện tại không có quyền update collection ingredients (rules).',
          );
        }
        rethrow;
      }
    }

    // 4. Tự động cập nhật trạng thái món ăn
    final changedIds = totalNeededMap.keys.toList();
    // Best-effort: menu availability update may be restricted by rules.
    try {
      await checkAndUpdateMenuAvailability(changedIds);
    } catch (e) {
      print('Warning: checkAndUpdateMenuAvailability failed (ignored): $e');
    }

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
        try {
          await pb
              .collection('menu_items')
              .update(menuItemId, body: {'in_stock': isEnough});
          print('Updated menu item $menuItemId in_stock = $isEnough');
        } on ClientException catch (e) {
          if (e.statusCode == 404) {
            print(
              'PocketBase 404 khi cập nhật in_stock (menu_items:update $menuItemId). '
              'Có thể do rules không cho phép user hiện tại update menu_items.',
            );
          } else {
            print('Error updating menu item $menuItemId in_stock: $e');
          }
        }
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
