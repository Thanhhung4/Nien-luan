// [DÁN TOÀN BỘ CODE NÀY VÀO lib/models/schedule_view.dart]

import 'package:myshop/models/schedule_exception.dart';
import 'package:myshop/models/staff_profile.dart';

// Enum thể hiện trạng thái làm việc cuối cùng
enum WorkStatus { working, absent, offDay }

// Lớp chứa thông tin ca làm việc đã được tổng hợp
class DailySchedule {
  final WorkStatus status;
  final List<String> shifts; // Các ca làm việc (VD: ['Ca sáng', 'Ca chiều'])

  DailySchedule({required this.status, this.shifts = const []});
}

// Lớp Logic chính
class ScheduleView {
  final StaffProfile profile;
  final List<ScheduleExceptionModel> exceptions;

  // Map từ weekday (1=Thứ 2) sang key của JSON ('T2')
  final Map<int, String> _weekdayMap = {
    1: 'T2',
    2: 'T3',
    3: 'T4',
    4: 'T5',
    5: 'T6',
    6: 'T7',
    7: 'CN',
  };

  ScheduleView({required this.profile, required this.exceptions});

  // Hàm quan trọng nhất: Trả về lịch làm việc cho một ngày cụ thể
  DailySchedule getScheduleForDay(DateTime day) {
    // 1. Kiểm tra "Ngoại lệ" (Exceptions) trước - (Ưu tiên cao nhất)
    for (final ex in exceptions) {
      if (isSameDay(ex.date, day)) {
        if (ex.type == ScheduleExceptionType.absent) {
          return DailySchedule(status: WorkStatus.absent); // Nghỉ
        }
        if (ex.type == ScheduleExceptionType.extraShift) {
          return DailySchedule(
            status: WorkStatus.working,
            shifts: [ex.shift ?? 'Ca làm thêm'], // Làm thêm
          );
        }
      }
    }

    // 2. Kiểm tra "Lịch Cố Định" (Default Schedule) - LOGIC MỚI
    final String weekdayKey = _weekdayMap[day.weekday]!; // Lấy T2, T3...

    // Lấy danh sách ca làm từ Map JSON
    // Nếu không có key `weekdayKey` trong Map, trả về list rỗng
    final List<String> shiftsForDay = profile.defaultSchedule[weekdayKey] ?? [];

    // Nếu danh sách ca làm của ngày hôm đó LÀ RỖNG
    if (shiftsForDay.isEmpty) {
      return DailySchedule(status: WorkStatus.offDay); // Ngày nghỉ
    }

    // Nếu hôm đó CÓ ca làm việc
    return DailySchedule(
      status: WorkStatus.working,
      shifts: shiftsForDay, // Lấy các ca cố định từ Map
    );
  }

  // Hàm helper kiểm tra 2 ngày có trùng nhau không
  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
