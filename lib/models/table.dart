import 'package:pocketbase/pocketbase.dart';

class TableModel {
  final String id;
  final String name;
  final String status; // 'empty' hoặc 'occupied'

  TableModel({required this.id, required this.name, required this.status});

  // Phương thức chuyển đổi từ PocketBase RecordModel sang TableModel
  factory TableModel.fromRecord(RecordModel record) {
    return TableModel(
      id: record.id,
      name: record.getStringValue('name'),
      status: record.getStringValue('status'),
    );
  }

  // Các getters tiện lợi
  bool get isOccupied => status == 'occupied';
  String get displayStatus => isOccupied ? 'Có khách' : 'Trống';
}
