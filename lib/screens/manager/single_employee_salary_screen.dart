// [CẬP NHẬT FILE: lib/screens/manager/single_employee_salary_screen.dart]

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

  // --- LOGIC TÍNH CÔNG & THỐNG KÊ ---
  Map<String, dynamic> _calculateStats(
    List<ScheduleExceptionModel> exceptions,
  ) {
    int totalDaysInMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      0,
    ).day;

    int standardWorkDays = 0; // Công chuẩn
    int actualWorkDays = 0; // Thực tế đi làm (theo lịch)
    int daysOff = 0; // Số ngày nghỉ (trên lịch)
    int extraShiftDays = 0; // MỚI: Số ngày làm thêm
    double totalPenalty = 0; // Tổng phạt
    int lateCount = 0; // Số lần trễ
    double totalBonus = 0; // Tổng thưởng

    // BƯỚC 1: Tính Tiền, Đếm trễ & Đếm làm thêm
    for (var ex in exceptions) {
      if (ex.type == ScheduleExceptionType.late) {
        totalPenalty += ex.penalty;
        lateCount++;
      }
      if (ex.type == ScheduleExceptionType.unexcused) {
        totalPenalty += ex.penalty;
      }
      if (ex.type == ScheduleExceptionType.extraShift) {
        totalBonus += ex.bonus;
        extraShiftDays++; // Đếm số ngoại lệ làm thêm
      }
    }

    // BƯỚC 2: Duyệt lịch để tính Công & Ngày nghỉ
    for (int i = 1; i <= totalDaysInMonth; i++) {
      final date = DateTime(_selectedMonth.year, _selectedMonth.month, i);
      final weekdayKey = _weekdayMap[date.weekday];

      final shifts = widget.profile.defaultSchedule[weekdayKey] ?? [];
      bool isScheduled = shifts.isNotEmpty;

      bool hasAbsenceException = exceptions.any(
        (e) =>
            isSameDay(e.date, date) &&
            (e.type == ScheduleExceptionType.absent ||
                e.type == ScheduleExceptionType.unexcused),
      );

      if (isScheduled) {
        standardWorkDays++;
        actualWorkDays++;

        if (hasAbsenceException) {
          daysOff++;
          actualWorkDays--; // Trừ ngày công thực tế nếu nghỉ
        }
      }
    }

    return {
      'standardDays': standardWorkDays,
      'actualDays': actualWorkDays,
      'offDays': daysOff,
      'extraShiftDays': extraShiftDays, // Trả về số ngày làm thêm
      'penalty': totalPenalty,
      'lateCount': lateCount,
      'bonus': totalBonus,
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
                final double bonus = stats['bonus'];
                final double netSalary = baseSalary + bonus - penalty;

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
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              formatCurrency(netSalary),
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: Colors.green,
                              ),
                            ),
                            const Divider(height: 30, thickness: 1),
                            _buildRow(
                              "Lương cứng",
                              formatCurrency(baseSalary),
                              isBold: true,
                            ),
                            const SizedBox(height: 12),
                            if (bonus > 0) ...[
                              _buildRow(
                                "Lương làm thêm",
                                "+${formatCurrency(bonus)}",
                                color: Colors.blue.shade700,
                                icon: Icons.add_circle_outline,
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (penalty > 0) ...[
                              _buildRow(
                                "Tổng Trừ/Phạt",
                                "-${formatCurrency(penalty)}",
                                color: Colors.red.shade700,
                                icon: Icons.remove_circle_outline,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 2. Thẻ Thống kê công
                    const Text(
                      "Thống kê công",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _buildRow(
                              "Số ngày công chuẩn",
                              "${stats['standardDays']} ngày",
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Divider(),
                            ),

                            _buildRow(
                              "Thực tế đi làm",
                              "${stats['actualDays']} ngày",
                              isBold: true,
                              color: Colors.blue.shade800,
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Divider(),
                            ),

                            // MỚI: HIỂN THỊ SỐ NGÀY LÀM THÊM
                            _buildRow(
                              "Số ngày làm thêm",
                              "${stats['extraShiftDays']} ngày",
                              color: Colors.purple,
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Divider(),
                            ),

                            _buildRow(
                              "Số ngày nghỉ (vắng)",
                              "${stats['offDays']} ngày",
                              color: Colors.orange.shade800,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 3. Thẻ Chi tiết ngoại lệ
                    const Text(
                      "Chi tiết ngoại lệ",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _buildRow(
                              "Số lần đi trễ",
                              "${stats['lateCount']} lần",
                            ),
                            const Divider(height: 24),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Lịch sử ghi nhận:",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            if (exceptions.isNotEmpty)
                              ...exceptions.map((e) {
                                String amountText = "";
                                Color amountColor = Colors.black;

                                if (e.penalty > 0) {
                                  amountText = "-${formatCurrency(e.penalty)}";
                                  amountColor = Colors.red;
                                } else if (e.bonus > 0) {
                                  amountText = "+${formatCurrency(e.bonus)}";
                                  amountColor = Colors.green;
                                }

                                String titleText = e.type.display;
                                if (e.type ==
                                        ScheduleExceptionType.extraShift &&
                                    e.shift != null &&
                                    e.shift!.isNotEmpty) {
                                  titleText += " (${e.shift})";
                                }

                                final dateStr = DateFormat(
                                  'dd/MM',
                                  'vi_VN',
                                ).format(e.date);

                                return Container(
                                  width: double.infinity, // full chiều ngang
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Hàng 1: ngày + nội dung
                                      Text(
                                        "$dateStr - $titleText",
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      // Hàng 2: số tiền, canh phải
                                      if (amountText.isNotEmpty)
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: Text(
                                            amountText,
                                            style: TextStyle(
                                              color: amountColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              })
                            else
                              const Padding(
                                padding: EdgeInsets.only(top: 12.0),
                                child: Text(
                                  "Không có ghi nhận ngoại lệ nào trong tháng này.",
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
    IconData? icon,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ],
        ),
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
