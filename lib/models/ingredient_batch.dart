// [FILE: lib/models/ingredient_batch.dart]

import 'package:pocketbase/pocketbase.dart';

class IngredientBatch {
  final String id;
  final String ingredientId;
  final double quantity; // Số lượng hiện tại (còn lại)
  final double initialQuantity; // Số lượng nhập ban đầu (MỚI)
  final DateTime importDate;
  final DateTime expiryDate; // Hạn sử dụng (MỚI)

  IngredientBatch({
    required this.id,
    required this.ingredientId,
    required this.quantity,
    required this.initialQuantity,
    required this.importDate,
    required this.expiryDate,
  });

  factory IngredientBatch.fromRecord(RecordModel record) {
    return IngredientBatch(
      id: record.id,
      ingredientId: record.getStringValue('ingredient'),
      quantity: record.getDoubleValue('quantity'),
      // Nếu dữ liệu cũ chưa có initial_quantity, tạm lấy bằng quantity
      initialQuantity: record.data['initial_quantity'] != null
          ? record.getDoubleValue('initial_quantity')
          : record.getDoubleValue('quantity'),
      importDate: DateTime.parse(
        record.getStringValue('import_date'),
      ).toLocal(),
      // Nếu dữ liệu cũ chưa có expiry_date, mặc định +30 ngày (để không lỗi app)
      expiryDate: record.getStringValue('expiry_date').isNotEmpty
          ? DateTime.parse(record.getStringValue('expiry_date')).toLocal()
          : DateTime.parse(
              record.getStringValue('import_date'),
            ).toLocal().add(const Duration(days: 30)),
    );
  }

  // Tính phần trăm còn lại (để vẽ thanh tiến độ)
  double get usagePercent =>
      (initialQuantity == 0) ? 0 : (quantity / initialQuantity);

  // Kiểm tra hết hạn
  bool get isExpired {
    final now = DateTime.now();
    // So sánh ngày (bỏ qua giờ phút)
    final today = DateTime(now.year, now.month, now.day);
    final exp = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    return today.isAfter(exp);
  }
}
