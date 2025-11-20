import 'package:pocketbase/pocketbase.dart';

enum ScheduleExceptionType {
  absent, // Nghỉ
  extraShift; // Làm thêm

  static ScheduleExceptionType fromString(String? typeString) {
    return (typeString == 'extra_shift')
        ? ScheduleExceptionType.extraShift
        : ScheduleExceptionType.absent;
  }

  String toJson() => name;
}

class ScheduleExceptionModel {
  final String id;
  final String staffProfileId; // Liên kết với staff_profiles
  final DateTime date;
  final ScheduleExceptionType type;
  final String? shift; // Dùng cho 'extra_shift' (VD: Thêm 'Ca sáng')

  ScheduleExceptionModel({
    required this.id,
    required this.staffProfileId,
    required this.date,
    required this.type,
    this.shift,
  });

  factory ScheduleExceptionModel.fromRecord(RecordModel record) {
    return ScheduleExceptionModel(
      id: record.id,
      staffProfileId: record.getStringValue('staff_profile'),
      date: DateTime.parse(record.getStringValue('date')).toLocal(),
      type: ScheduleExceptionType.fromString(record.getStringValue('type')),
      shift: record.getStringValue('shift'), // Có thể rỗng
    );
  }
}
