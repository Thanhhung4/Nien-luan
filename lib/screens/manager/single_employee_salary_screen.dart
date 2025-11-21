// [FILE MỚI: lib/screens/manager/single_employee_salary_screen.dart]

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:myshop/models/schedule_exception.dart';
import 'package:myshop/models/staff_profile.dart';
import 'package:myshop/services/pocketbase_service.dart';
import 'package:myshop/utils/currency_formatter.dart';

class SingleEmployeeSalaryScreen extends StatefulWidget {
  final StaffProfile profile;

  const SingleEmployeeSalaryScreen({super.key, required this.profile});

  @override
  State<SingleEmployeeSalaryScreen> createState() =>
      _SingleEmployeeSalaryScreenState();
}

class _SingleEmployeeSalaryScreenState
    extends State<SingleEmployeeSalaryScreen> {
  final pbService = PocketBaseService.instance;
  DateTime _selectedMonth = DateTime.now();
  late Future<List<ScheduleExceptionModel>> _exceptionsFuture;

  // Map để mapping thứ trong tuần
  final Map<int, String> _weekdayMap = {
    1: 'T2',
    2: 'T3',
    3: 'T4',
    4: 'T5',
    5: 'T6',
    6: 'T7',
    7: 'CN',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final startDate = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final endDate = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

    setState(() {
      _exceptionsFuture = pbService.schedules.getScheduleExceptions(
        staffProfileId: widget.profile.id,
        startDate: startDate,
        endDate: endDate,
      );
    });
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + offset,
        1,
      );
    });
    _loadData();
  }

  // --- LOGIC TÍNH CÔNG ---
  Map<String, dynamic> _calculateStats(
    List<ScheduleExceptionModel> exceptions,
  ) {
    int totalDaysInMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      0,
    ).day;
    int standardWorkDays = 0; // Số ngày lẽ ra phải làm theo lịch
    int actualWorkDays = 0; // Số ngày thực tế đi làm
    int daysOff = 0; // Số ngày nghỉ (có phép + không phép + ngày nghỉ lịch)
    double totalPenalty = 0;
    int lateCount = 0;

    // 1. Duyệt qua từng ngày trong tháng để tính công chuẩn
    for (int i = 1; i <= totalDaysInMonth; i++) {
      final date = DateTime(_selectedMonth.year, _selectedMonth.month, i);
      final weekdayKey = _weekdayMap[date.weekday];

      // Kiểm tra xem ngày này có trong lịch cố định không
      final shifts = widget.profile.defaultSchedule[weekdayKey] ?? [];
      bool isScheduled = shifts.isNotEmpty;

      if (isScheduled) {
        standardWorkDays++;

        // Kiểm tra xem có xin nghỉ (exception) vào ngày này không
        // Tìm exception khớp ngày
        final ex = exceptions.firstWhere(
          (e) =>
              isSameDay(e.date, date) &&
              (e.type == ScheduleExceptionType.absent ||
                  e.type == ScheduleExceptionType.unexcused),
          orElse: () => ScheduleExceptionModel(
            id: '',
            staffProfileId: '',
            date: DateTime(1900),
            type: ScheduleExceptionType.extraShift,
          ), // Dummy
        );

        if (ex.id.isNotEmpty) {
          // Có ngoại lệ nghỉ -> Không tính công
          daysOff++;
          if (ex.type == ScheduleExceptionType.unexcused) {
            totalPenalty += ex.penalty;
          }
        } else {
          // Không nghỉ -> Có đi làm
          actualWorkDays++;
        }
      } else {
        // Ngày nghỉ theo lịch
        daysOff++;
        // Check nếu có làm thêm (extraShift)
        final ex = exceptions.firstWhere(
          (e) =>
              isSameDay(e.date, date) &&
              e.type == ScheduleExceptionType.extraShift,
          orElse: () => ScheduleExceptionModel(
            id: '',
            staffProfileId: '',
            date: DateTime(1900),
            type: ScheduleExceptionType.extraShift,
          ),
        );
        if (ex.id.isNotEmpty && ex.date.year != 1900) {
          actualWorkDays++; // Tính là đi làm (làm thêm)
          daysOff--; // Giảm ngày nghỉ xuống
        }
      }
    }

    // 2. Tính tiền phạt đi trễ (Late không ảnh hưởng ngày công, chỉ trừ tiền)
    for (var ex in exceptions) {
      if (ex.type == ScheduleExceptionType.late) {
        totalPenalty += ex.penalty;
        lateCount++;
      }
    }

    return {
      'standardDays': standardWorkDays,
      'actualDays': actualWorkDays,
      'offDays': daysOff,
      'penalty': totalPenalty,
      'lateCount': lateCount,
    };
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết Lương'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Thanh chọn tháng
          Container(
            color: Colors.indigo.shade50,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeMonth(-1),
                ),
                Text(
                  "Tháng ${DateFormat('MM/yyyy').format(_selectedMonth)}",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
          ),

          Expanded(
            child: FutureBuilder<List<ScheduleExceptionModel>>(
              future: _exceptionsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Lỗi: ${snapshot.error}'));
                }

                final exceptions = snapshot.data ?? [];
                final stats = _calculateStats(exceptions);

                final double baseSalary = widget.profile.salary;
                final double penalty = stats['penalty'];
                final double netSalary = baseSalary - penalty;

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // 1. Thẻ Tổng Lương
                    Card(
                      elevation: 4,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Text(
                              "THỰC LĨNH",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              formatCurrency(netSalary),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const Divider(height: 30),
                            _buildRow(
                              "Lương cứng",
                              formatCurrency(baseSalary),
                              isBold: true,
                            ),
                            const SizedBox(height: 8),
                            _buildRow(
                              "Tổng Trừ/Phạt",
                              "-${formatCurrency(penalty)}",
                              color: Colors.red,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Thẻ Chấm công
                    const Text(
                      "Thống kê công",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _buildRow(
                              "Số ngày công chuẩn",
                              "${stats['standardDays']} ngày",
                            ),
                            const Divider(),
                            _buildRow(
                              "Thực tế đi làm",
                              "${stats['actualDays']} ngày",
                              isBold: true,
                              color: Colors.blue,
                            ),
                            const Divider(),
                            _buildRow(
                              "Số ngày nghỉ",
                              "${stats['offDays']} ngày",
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 3. Thẻ Vi phạm
                    const Text(
                      "Chi tiết vi phạm",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _buildRow(
                              "Số lần đi trễ",
                              "${stats['lateCount']} lần",
                            ),
                            if (exceptions.isNotEmpty) ...[
                              const Divider(),
                              const SizedBox(height: 8),
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  "Lịch sử ghi nhận:",
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                              ...exceptions.map(
                                (e) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  title: Text(
                                    "${DateFormat('dd/MM').format(e.date)} - ${e.type.display}",
                                  ),
                                  trailing: Text(
                                    "-${formatCurrency(e.penalty)}",
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              ),
                            ] else
                              const Padding(
                                padding: EdgeInsets.only(top: 8.0),
                                child: Text(
                                  "Không có ghi nhận vi phạm nào.",
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 16)),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}
