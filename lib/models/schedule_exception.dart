// [CẬP NHẬT FILE: lib/models/schedule_exception.dart]

import 'package:pocketbase/pocketbase.dart';

enum ScheduleExceptionType {
  absent, // Nghỉ có phép
  extraShift, // Làm thêm
  late, // Đi trễ (MỚI)
  unexcused; // Nghỉ không phép (MỚI)

  static ScheduleExceptionType fromString(String? typeString) {
    switch (typeString) {
      case 'extra_shift':
        return ScheduleExceptionType.extraShift;
      case 'late':
        return ScheduleExceptionType.late;
      case 'unexcused_absence':
        return ScheduleExceptionType.unexcused;
      default:
        return ScheduleExceptionType.absent;
    }
  }

  String toJson() {
    switch (this) {
      case ScheduleExceptionType.extraShift:
        return 'extra_shift';
      case ScheduleExceptionType.late:
        return 'late';
      case ScheduleExceptionType.unexcused:
        return 'unexcused_absence';
      default:
        return 'absent';
    }
  }

  // Text hiển thị tiếng Việt
  String get display {
    switch (this) {
      case ScheduleExceptionType.absent:
        return 'Nghỉ có phép';
      case ScheduleExceptionType.extraShift:
        return 'Làm thêm';
      case ScheduleExceptionType.late:
        return 'Đi trễ';
      case ScheduleExceptionType.unexcused:
        return 'Nghỉ không phép';
    }
  }
}

class ScheduleExceptionModel {
  final String id;
  final String staffProfileId;
  final DateTime date;
  final ScheduleExceptionType type;
  final String? shift;
  final double penalty; // (MỚI) Số tiền phạt

  ScheduleExceptionModel({
    required this.id,
    required this.staffProfileId,
    required this.date,
    required this.type,
    this.shift,
    this.penalty = 0.0,
  });

  factory ScheduleExceptionModel.fromRecord(RecordModel record) {
    return ScheduleExceptionModel(
      id: record.id,
      staffProfileId: record.getStringValue('staff_profile'),
      date: DateTime.parse(record.getStringValue('date')).toLocal(),
      type: ScheduleExceptionType.fromString(record.getStringValue('type')),
      shift: record.getStringValue('shift'),
      penalty: record.getDoubleValue('penalty'), // Lấy từ DB
    );
  }
}
