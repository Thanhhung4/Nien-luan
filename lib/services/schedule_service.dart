import 'package:pocketbase/pocketbase.dart';
import 'package:myshop/models/schedule_exception.dart';
import 'package:intl/intl.dart';

class ScheduleService {
  final PocketBase pb;
  ScheduleService(this.pb);

  /// Lấy các "Ngoại lệ" (nghỉ/làm thêm) của 1 nhân viên trong khoảng thời gian
  Future<List<ScheduleExceptionModel>> getScheduleExceptions({
    required String staffProfileId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final startFilter = DateFormat('yyyy-MM-dd').format(startDate);
      final endFilter = DateFormat('yyyy-MM-dd').format(endDate);

      final filter =
          'staff_profile = \'$staffProfileId\' && date >= \'$startFilter\' && date <= \'$endFilter\'';

      final records = await pb
          .collection('schedule_exceptions')
          .getFullList(filter: filter, sort: 'date');
      return records.map((r) => ScheduleExceptionModel.fromRecord(r)).toList();
    } catch (e) {
      print('ScheduleService - Error fetching exceptions: $e');
      throw Exception('Failed to load schedule exceptions: $e');
    }
  }

  /// (Cho Quản lý) Tạo một "Ngoại lệ" mới (Nghỉ hoặc Làm thêm)
  // 1. Cập nhật hàm createScheduleException
  Future<void> createScheduleException({
    required String staffProfileId,
    required DateTime date,
    required ScheduleExceptionType type,
    String? shift,
    double penalty = 0.0, // Thêm tham số này
  }) async {
    try {
      final body = <String, dynamic>{
        'staff_profile': staffProfileId,
        'date': DateFormat('yyyy-MM-dd').format(date.toUtc()),
        'type': type.toJson(),
        'shift': (type == ScheduleExceptionType.extraShift) ? shift : null,
        'penalty': penalty, // Gửi lên DB
      };
      await pb.collection('schedule_exceptions').create(body: body);
    } catch (e) {
      print('ScheduleService - Error creating exception: $e');
      throw Exception('Failed to create schedule exception: $e');
    }
  }

  // 2. (MỚI) Hàm lấy tất cả ngoại lệ trong tháng (để tính lương)
  Future<List<ScheduleExceptionModel>> getAllExceptionsInMonth(
    DateTime month,
  ) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);
    final startStr = DateFormat('yyyy-MM-dd').format(start);
    final endStr = DateFormat('yyyy-MM-dd').format(end);

    final records = await pb
        .collection('schedule_exceptions')
        .getFullList(filter: 'date >= "$startStr" && date <= "$endStr"');
    return records.map((r) => ScheduleExceptionModel.fromRecord(r)).toList();
  }

  /// (Cho Quản lý) Xóa một "Ngoại lệ"
  Future<void> deleteScheduleException(String exceptionId) async {
    try {
      await pb.collection('schedule_exceptions').delete(exceptionId);
    } catch (e) {
      print('ScheduleService - Error deleting exception: $e');
      throw Exception('Failed to delete schedule exception: $e');
    }
  }
}
