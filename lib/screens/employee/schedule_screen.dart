// [DÁN TOÀN BỘ CODE NÀY VÀO lib/screens/employee/schedule_screen.dart]

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:myshop/models/schedule_exception.dart';
import 'package:myshop/models/staff_profile.dart';
import 'package:myshop/services/pocketbase_service.dart';
import 'package:myshop/models/schedule_view.dart';
import 'package:table_calendar/table_calendar.dart';

class ScheduleScreen extends StatefulWidget {
  final StaffProfile profile;
  const ScheduleScreen({super.key, required this.profile});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final pbService = PocketBaseService.instance;

  // Trạng thái của Lịch
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.week; // Mặc định xem Tuần

  // Logic tổng hợp lịch
  ScheduleView? _scheduleView;
  late Future<void> _loadScheduleFuture;

  // --- SỬA Ở ĐÂY ---
  // Lưu profile vào state để có thể cập nhật
  late StaffProfile _currentProfile;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _currentProfile = widget.profile; // <-- SỬA Ở ĐÂY

    // Tải dữ liệu ngoại lệ khi mở màn hình
    // _loadExceptions giờ sẽ tự tạo _scheduleView
    _loadScheduleFuture = _loadScheduleData(_focusedDay); // <-- SỬA Ở ĐÂY
  }

  // --- HÀM NÀY ĐÃ ĐƯỢC SỬA LẠI (SỬA LỖI KHÔNG HIỂN THỊ) ---
  // Tải cả Profile (lịch cố định) VÀ Ngoại lệ
  Future<void> _loadScheduleData(DateTime date) async {
    // Tải dữ liệu +/- 1 tháng xung quanh ngày được chọn
    final startDate = DateTime(date.year, date.month - 1, 1);
    final endDate = DateTime(date.year, date.month + 2, 0);

    // Sử dụng Future.wait để tải cả hai song song
    try {
      final results = await Future.wait([
        // 1. Tải lại profile mới nhất (để lấy default_schedule mới)
        pbService.users.getStaffProfile(_currentProfile.id),

        // 2. Tải ngoại lệ
        pbService.schedules.getScheduleExceptions(
          staffProfileId: _currentProfile.id,
          startDate: startDate,
          endDate: endDate,
        ),
      ]);

      // Gán kết quả
      final newProfile = results[0] as StaffProfile;
      final exceptions = results[1] as List<ScheduleExceptionModel>;

      if (mounted) {
        setState(() {
          // Cập nhật cả profile và scheduleView
          _currentProfile = newProfile;
          _scheduleView = ScheduleView(
            profile: _currentProfile, // <-- Dùng profile MỚI
            exceptions: exceptions,
          );
        });
      }
    } catch (e) {
      print("Lỗi khi tải _loadScheduleData: $e");
      if (mounted) {
        // Hiển thị lỗi nếu có
        setState(() {
          // Vẫn tạo scheduleView với profile cũ để app không crash
          _scheduleView = ScheduleView(
            profile: _currentProfile,
            exceptions: [],
          );
        });
      }
      // (Bạn có thể thêm 1 biến _error để hiển thị lỗi ra UI)
    }
  }

  // Hàm này được TableCalendar gọi để lấy lịch cho 1 ngày
  DailySchedule _getScheduleForDay(DateTime day) {
    if (_scheduleView == null) {
      // Nếu chưa tải xong, tạm thời trả về 'Ngày nghỉ'
      return DailySchedule(status: WorkStatus.offDay);
    }
    return _scheduleView!.getScheduleForDay(day);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch làm việc'),
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder(
        future: _loadScheduleFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi tải lịch: ${snapshot.error}'));
          }

          // Khi đã tải xong
          return Column(
            children: [
              _buildTableCalendar(),
              const Divider(height: 1),
              // Hiển thị chi tiết ca làm của ngày được chọn
              _buildSelectedDayInfo(),
            ],
          );
        },
      ),
    );
  }

  // Widget hiển thị Lịch (Tuần/Tháng)
  Widget _buildTableCalendar() {
    return TableCalendar(
      locale: 'vi_VN',
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
      calendarFormat: _calendarFormat,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),

      // --- SỬA Ở ĐÂY ---
      // Xử lý khi đổi trang (tháng/tuần)
      onPageChanged: (focusedDay) {
        if (!isSameDay(_focusedDay, focusedDay)) {
          _focusedDay = focusedDay;
          // Tải lại cả profile và ngoại lệ cho tháng mới
          setState(() {
            _loadScheduleFuture = _loadScheduleData(focusedDay);
          });
        }
      },
      // --- KẾT THÚC SỬA ---

      // Xử lý khi bấm vào 1 ngày
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
      },

      // Xử lý khi đổi định dạng (Tuần/Tháng)
      onFormatChanged: (format) {
        setState(() {
          _calendarFormat = format;
        });
      },

      // Tùy biến giao diện ngày
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, focusedDay) {
          final schedule = _getScheduleForDay(day);
          if (schedule.status == WorkStatus.working) {
            return Center(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  shape: BoxShape.circle,
                ),
                width: 36,
                height: 36,
                child: Center(
                  child: Text(
                    '${day.day}',
                    style: const TextStyle(color: Colors.black),
                  ),
                ),
              ),
            );
          }
          if (schedule.status == WorkStatus.absent) {
            return Center(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  shape: BoxShape.circle,
                ),
                width: 36,
                height: 36,
                child: Center(
                  child: Text(
                    '${day.day}',
                    style: const TextStyle(
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ),
              ),
            );
          }
          return null; // Dùng giao diện mặc định (ngày nghỉ)
        },
      ),
    );
  }

  // Widget hiển thị ca làm việc của ngày đã chọn
  Widget _buildSelectedDayInfo() {
    if (_selectedDay == null) return const SizedBox.shrink();

    final schedule = _getScheduleForDay(_selectedDay!);

    String title;
    String subtitle;
    IconData icon;
    Color color;

    switch (schedule.status) {
      case WorkStatus.working:
        title = 'Đi làm';
        subtitle = schedule.shifts.join(', '); // VD: "Ca sáng, Ca chiều"
        icon = Icons.work_history;
        color = Colors.blue;
        break;
      case WorkStatus.absent:
        title = 'Nghỉ phép/Ốm';
        subtitle = 'Nghỉ cả ngày';
        icon = Icons.beach_access;
        color = Colors.orange;
        break;
      case WorkStatus.offDay:
        title = 'Ngày nghỉ';
        subtitle = 'Không có ca làm việc';
        icon = Icons.weekend;
        color = Colors.grey;
        break;
    }

    final dayTitle = DateFormat(
      'EEEE, dd/MM/yyyy',
      'vi_VN',
    ).format(_selectedDay!);

    return ListTile(
      leading: Icon(icon, color: color, size: 40),
      title: Text(
        dayTitle,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text('$title ($subtitle)'),
    );
  }
}
