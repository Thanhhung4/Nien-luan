// [FILE MỚI: lib/models/spoilage_log.dart]
import 'package:pocketbase/pocketbase.dart';

class SpoilageLog {
  final String id;
  final String ingredientName;
  final double quantity;
  final double totalLoss; // Số tiền bị mất
  final DateTime created; // Ngày tiêu hủy

  SpoilageLog({
    required this.id,
    required this.ingredientName,
    required this.quantity,
    required this.totalLoss,
    required this.created,
  });

  factory SpoilageLog.fromRecord(RecordModel record) {
    return SpoilageLog(
      id: record.id,
      ingredientName: record.getStringValue('ingredient_name'),
      quantity: record.getDoubleValue('quantity'),
      totalLoss: record.getDoubleValue('total_loss'),
      created: DateTime.parse(record.created).toLocal(),
    );
  }
}
