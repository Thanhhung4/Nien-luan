import 'package:pocketbase/pocketbase.dart';

// Model cơ bản cho bảng 'orders'
class OrderModel {
  final String id;
  final String tableId;
  final double totalPrice;
  final String? createdById; // Đặt là nullable (String?)
  final DateTime created;
  final DateTime updated;

  OrderModel({
    required this.id,
    required this.tableId,
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
      totalPrice: record.getDoubleValue('total_price'),
      createdById: createdBy.isNotEmpty
          ? createdBy
          : null, // Xử lý giá trị null
      created: DateTime.parse(record.getStringValue('created')).toLocal(),
      updated: DateTime.parse(record.getStringValue('updated')).toLocal(),
    );
  }
}
