import 'package:pocketbase/pocketbase.dart';

class OrderItemModel {
  final String id;
  final String orderId; // ID của Hóa đơn (từ relation 'order')
  final String menuItemId; // ID của Món ăn (từ relation 'menu_item')
  final int quantity; // Số lượng
  final double price; // Giá tại thời điểm gọi món

  OrderItemModel({
    required this.id,
    required this.orderId,
    required this.menuItemId,
    required this.quantity,
    required this.price,
  });

  /// Phương thức factory để chuyển đổi từ PocketBase RecordModel
  factory OrderItemModel.fromRecord(RecordModel record) {
    return OrderItemModel(
      id: record.id,
      orderId: record.getStringValue('order'),
      menuItemId: record.getStringValue('menu_item'),
      quantity: record.getIntValue('quantity'), // Dùng getIntValue an toàn hơn
      price: record.getDoubleValue('price'),
    );
  }
}
