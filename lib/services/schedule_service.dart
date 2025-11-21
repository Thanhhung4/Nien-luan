// [CẬP NHẬT FILE: lib/services/schedule_service.dart]

import 'package:intl/intl.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:myshop/models/schedule_exception.dart';

class ScheduleService {
  final PocketBase pb;

  ScheduleService(this.pb);

  // Lấy danh sách ngoại lệ theo khoảng thời gian
  Future<List<ScheduleExceptionModel>> getScheduleExceptions({
    required String staffProfileId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final startStr = DateFormat('yyyy-MM-dd').format(startDate);
      final endStr = DateFormat('yyyy-MM-dd').format(endDate);

      final records = await pb
          .collection('schedule_exceptions')
          .getFullList(
            filter:
                'staff_profile = "$staffProfileId" && date >= "$startStr" && date <= "$endStr"',
            sort: 'date',
          );

      return records.map((r) => ScheduleExceptionModel.fromRecord(r)).toList();
    } catch (e) {
      print('ScheduleService - Error fetching exceptions: $e');
      // Trả về list rỗng thay vì crash app nếu lỗi mạng
      return [];
    }
  }

  // Lấy tất cả ngoại lệ trong tháng (Dùng cho báo cáo lương)
  Future<List<ScheduleExceptionModel>> getAllExceptionsInMonth(
    DateTime month,
  ) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);

    // Sửa lỗi timezone: Format trực tiếp ngày local, không convert toUtc ở đây
    final startStr = DateFormat('yyyy-MM-dd').format(start);
    final endStr = DateFormat('yyyy-MM-dd').format(end);

    try {
      final records = await pb
          .collection('schedule_exceptions')
          .getFullList(filter: 'date >= "$startStr" && date <= "$endStr"');
      return records.map((r) => ScheduleExceptionModel.fromRecord(r)).toList();
    } catch (e) {
      print('Error fetching monthly exceptions: $e');
      return [];
    }
  }

  // Tạo ngoại lệ mới
  Future<void> createScheduleException({
    required String staffProfileId,
    required DateTime date,
    required ScheduleExceptionType type,
    String? shift,
    double penalty = 0.0,
    double bonus = 0.0,
  }) async {
    try {
      final body = <String, dynamic>{
        'staff_profile': staffProfileId,
        // SỬA LỖI: Bỏ .toUtc() để tránh bị lệch ngày do múi giờ
        'date': DateFormat('yyyy-MM-dd').format(date),
        'type': type.toJson(),
        'shift': (type == ScheduleExceptionType.extraShift) ? shift : null,
        'penalty': penalty,
        'bonus': bonus,
      };
      await pb.collection('schedule_exceptions').create(body: body);
    } catch (e) {
      print('ScheduleService - Error creating exception: $e');
      throw Exception('Failed to create schedule exception: $e');
    }
  }

  // Xóa ngoại lệ
  Future<void> deleteScheduleException(String id) async {
    try {
      await pb.collection('schedule_exceptions').delete(id);
    } catch (e) {
      print('ScheduleService - Error deleting exception: $e');
      throw Exception('Failed to delete schedule exception: $e');
    }
  }
}
