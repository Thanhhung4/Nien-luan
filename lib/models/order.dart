import 'package:pocketbase/pocketbase.dart';

// Enum trạng thái hóa đơn
enum OrderStatus {
  pending, // Chờ thanh toán / Đang phục vụ
  completed, // Đã hoàn thành (cần thêm vào)
  paid; // Đã thanh toán / Hoàn thành

  // Getter 'display' cần thiết để hiển thị trạng thái bằng tiếng Việt
  String get display {
    switch (this) {
      case OrderStatus.pending:
        return 'Đang phục vụ';
      case OrderStatus.completed:
        return 'Đã hoàn thành'; // Hiển thị cho trạng thái completed
      case OrderStatus.paid:
        return 'Đã thanh toán';
    }
  }

  // Phương thức chuyển đổi từ chuỗi (dùng trong PocketBaseService)
  static OrderStatus fromString(String? statusString) {
    switch (statusString) {
      case 'completed':
        return OrderStatus.completed;
      case 'paid':
        return OrderStatus.paid;
      default:
        return OrderStatus.pending; // Mặc định là pending
    }
  }

  /// Chuyển đổi từ Enum sang String (để gửi lên DB)
  String toJson() {
    return name; // 'pending', 'completed', 'paid'
  }
}

// Model cơ bản cho bảng 'orders'
class OrderModel {
  final String id;
  final String tableId;
  final OrderStatus status;
  final double totalPrice;
  final String? createdById; // Đặt là nullable (String?)
  final DateTime created;
  final DateTime updated;

  OrderModel({
    required this.id,
    required this.tableId,
    required this.status,
    required this.totalPrice,
    this.createdById, // Bỏ 'required' vì đã là nullable
    required this.created,
    required this.updated,
  });

  factory OrderModel.fromRecord(RecordModel record) {
    final createdBy = record.getStringValue('created_by');

    return OrderModel(
      id: record.id,
      tableId: record.getStringValue('table'),
      status: OrderStatus.fromString(record.getStringValue('status')),
      totalPrice: record.getDoubleValue('total_price'),
      createdById: createdBy.isNotEmpty
          ? createdBy
          : null, // Xử lý giá trị null
      created: DateTime.parse(record.getStringValue('created')).toLocal(),
      updated: DateTime.parse(record.getStringValue('updated')).toLocal(),
    );
  }
}
