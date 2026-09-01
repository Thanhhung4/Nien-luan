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

  String get displayTableName {
    final name = tableName.trim();
    if (name.isEmpty) return 'Tại quán';

    final lower = name.toLowerCase();
    if (lower.contains('tại quán') || lower.contains('tai quan')) {
      return 'Tại quán';
    }

    if (lower.contains('bàn') || lower.contains('ban ')) {
      return name;
    }

    // If it's just a number or any other label, prefix with "Bàn "
    return 'Bàn $name';
  }

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
    RecordModel? creatorRecord, { // Nhận thêm RecordModel của người tạo
    String? tableNameFallback,
  }) {
    // CẬP NHẬT: Thay thế 'username' bằng 'name' theo yêu cầu (Giả định trường 'name' có trong collection 'users')
    // Nếu trường 'name' không tồn tại, nó sẽ là null.
    final creatorName = creatorRecord?.getStringValue('name');

    String rawTableValue = record.getStringValue('table').trim();
    if (rawTableValue.isEmpty) {
      try {
        final tableList = record.get<List<String>?>('table');
        if (tableList != null && tableList.isNotEmpty) {
          rawTableValue = tableList.first.trim();
        }
      } catch (_) {
        // ignore
      }
    }

    if (rawTableValue.isEmpty) {
      try {
        final tableList = record.get<List<dynamic>?>('table');
        if (tableList != null && tableList.isNotEmpty) {
          rawTableValue = tableList.first.toString().trim();
        }
      } catch (_) {
        // ignore
      }
    }

    if (rawTableValue.isEmpty) {
      try {
        final tableMap = record.get<Map<String, dynamic>?>('table');
        if (tableMap != null) {
          rawTableValue =
              (tableMap['id'] ?? tableMap['recordId'] ?? tableMap['name'] ?? '')
                  .toString()
                  .trim();
        }
      } catch (_) {
        // ignore
      }
    }

    if (rawTableValue.isEmpty) {
      try {
        final any = record.get<dynamic>('table');
        if (any is String && any.trim().isNotEmpty) {
          rawTableValue = any.trim();
        } else if (any is List && any.isNotEmpty) {
          rawTableValue = any.first.toString().trim();
        } else if (any is Map && any['id'] != null) {
          rawTableValue = any['id'].toString().trim();
        }
      } catch (_) {
        // ignore
      }
    }

    bool looksLikePocketBaseId(String value) {
      // PocketBase default record id is typically a 15-char base62-like string.
      // If `orders.table` is plain text (e.g. "Bàn 1"), treat it as a name.
      return RegExp(r'^[a-z0-9]{15}$', caseSensitive: false).hasMatch(value);
    }

    final rawTableName =
        (rawTableValue.isNotEmpty && !looksLikePocketBaseId(rawTableValue))
        ? rawTableValue
        : '';

    final normalizedFallback = (tableNameFallback ?? '').trim();

    return OrderViewModel(
      id: record.id,
      tableId: rawTableValue,
      tableName:
          tableRecord?.getStringValue('name') ??
          (normalizedFallback.isNotEmpty ? normalizedFallback : rawTableName),
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
