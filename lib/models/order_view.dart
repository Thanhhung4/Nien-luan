// *** MODEL VIEW CHO HÓA ĐƠN HOÀN THÀNH (Nên chuyển ra file riêng) ***
// LƯU Ý: Lớp này nên được chuyển sang file riêng (ví dụ: lib/models/order_view.dart)
import 'package:pocketbase/pocketbase.dart';

class OrderViewModel {
  final String id;
  final String tableId;
  final String tableName; // Tên bàn
  final double totalPrice;
  final String createdById;
  final String createdByUsername; // Thêm tên người tạo hóa đơn
  final DateTime created;
  final DateTime updated;

  OrderViewModel({
    required this.id,
    required this.tableId,
    required this.tableName,
    required this.totalPrice,
    required this.createdById,
    required this.createdByUsername, // Cập nhật Constructor
    required this.created,
    required this.updated,
  });

  factory OrderViewModel.fromRecord(
    RecordModel record,
    RecordModel? tableRecord,
    RecordModel? creatorRecord, // Nhận thêm RecordModel của người tạo
  ) {
    // CẬP NHẬT: Thay thế 'username' bằng 'name' theo yêu cầu (Giả định trường 'name' có trong collection 'users')
    // Nếu trường 'name' không tồn tại, nó sẽ là null.
    final creatorName = creatorRecord?.getStringValue('name');

    return OrderViewModel(
      id: record.id,
      tableId: record.getStringValue('table'),
      tableName: tableRecord?.getStringValue('name') ?? 'Tại quán',
      totalPrice: record.getDoubleValue('total_price'),
      createdById: record.getStringValue('created_by'),

      // Lấy 'name' từ creatorRecord. Nếu null, rỗng, hoặc không có trường 'name', dùng email rồi mới ID (rút gọn)
      createdByUsername: (creatorName?.isNotEmpty == true)
          ? creatorName!
          : (creatorRecord?.getStringValue('email') ?? // Fallback về email
                'User ID: ${record.getStringValue('created_by').substring(0, 8)}...'), // Fallback cuối

      created: DateTime.parse(
        record.getStringValue('created'),
      ).toLocal(), // Chuyển về giờ địa phương
      updated: DateTime.parse(
        record.getStringValue('updated'),
      ).toLocal(), // Chuyển về giờ địa phương
    );
  }
}
