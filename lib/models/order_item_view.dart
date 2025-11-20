// [DÁN TOÀN BỘ CODE NÀY VÀO lib/models/order_item_view.dart]

import 'package:myshop/models/menu_item.dart';

/// Lớp này là một "View Model" đặc biệt,
/// dùng để gộp dữ liệu từ `order_items` (số lượng)
/// và `menu_items` (tên, giá, ảnh).
///
/// Nó được tạo thủ công bên trong `PocketBaseService`
/// sau khi "expand" (mở rộng) quan hệ.
class OrderItemView {
  final String id; // ID của order_item
  final int quantity;
  final double price; // Giá tại thời điểm đặt
  final MenuItemModel menuItem; // Thông tin món ăn (đã expand)

  // --- THÊM TRƯỜNG MỚI ---
  final String? notes;
  // --- KẾT THÚC THÊM ---

  OrderItemView({
    required this.id,
    required this.quantity,
    required this.price,
    required this.menuItem,
    this.notes, // <-- Thêm vào constructor
  });

  /// Tính thành tiền cho món này (SL * Giá)
  double get subtotal => price * quantity;
}
