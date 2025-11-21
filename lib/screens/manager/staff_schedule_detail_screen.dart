// [DÁN TOÀN BỘ CODE NÀY VÀO lib/screens/manager/staff_schedule_detail_screen.dart]

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:myshop/models/schedule_exception.dart';
import 'package:myshop/models/staff_profile.dart';
import 'package:myshop/services/pocketbase_service.dart';
import 'package:myshop/widgets/manager/add_exception_dialog.dart';
import 'package:myshop/utils/currency_formatter.dart'; // <-- Import mới

// Định nghĩa các hằng số cho form
const List<String> _allWorkDays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
const List<String> _allShifts = ['Ca sáng', 'Ca chiều', 'Ca tối'];

class StaffScheduleDetailScreen extends StatefulWidget {
  final StaffProfile profile;

  const StaffScheduleDetailScreen({super.key, required this.profile});

  @override
  State<StaffScheduleDetailScreen> createState() =>
      _StaffScheduleDetailScreenState();
}

class _StaffScheduleDetailScreenState extends State<StaffScheduleDetailScreen>
    with SingleTickerProviderStateMixin {
  final pbService = PocketBaseService.instance;

  // State cho Tab Ngoại lệ
  late Future<List<ScheduleExceptionModel>> _exceptionsFuture;
  final DateTime _startDate = DateTime.now().subtract(
    const Duration(days: 30),
  ); // Load rộng ra xíu
  final DateTime _endDate = DateTime.now().add(const Duration(days: 60));

  // State cho Tab Lịch Cố Định
  final _formKey = GlobalKey<FormState>();
  late Map<String, Set<String>> _scheduleMap;
  bool _isSavingSchedule = false;

  @override
  void initState() {
    super.initState();
    _loadExceptions();

    _scheduleMap = {};
    for (var day in _allWorkDays) {
      final shiftsForDay = widget.profile.defaultSchedule[day] ?? [];
      _scheduleMap[day] = Set<String>.from(shiftsForDay);
    }
  }

  Future<void> _loadExceptions() async {
    if (mounted) {
      setState(() {
        _exceptionsFuture = pbService.schedules.getScheduleExceptions(
          staffProfileId: widget.profile.id,
          startDate: _startDate,
          endDate: _endDate,
        );
      });
    }
  }

  // Cập nhật hàm này để nhận thêm penalty
  Future<void> _handleCreateException({
    required DateTime date,
    required ScheduleExceptionType type,
    String? shift,
    double penalty = 0.0, // <-- Thêm tham số này
    double bonus = 0.0, // <-- Thêm tham số bonus
  }) async {
    try {
      await pbService.schedules.createScheduleException(
        staffProfileId: widget.profile.id,
        date: date,
        type: type,
        shift: shift,
        penalty: penalty, // <-- Truyền lên service
        bonus: bonus,
      );
      if (mounted) _showSnackbar('Đã thêm ngoại lệ', Colors.green);
      _loadExceptions();
    } catch (e) {
      if (mounted) _showSnackbar('Lỗi: $e', Colors.red);
      throw e;
    }
  }

  Future<void> _handleDeleteException(String exceptionId) async {
    try {
      await pbService.schedules.deleteScheduleException(exceptionId);
      _loadExceptions();
    } catch (e) {
      if (mounted) _showSnackbar('Lỗi khi xóa: $e', Colors.red);
    }
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AddExceptionDialog(
          onSave: _handleCreateException,
          initialDate: DateTime.now(),
          defaultSchedule: widget.profile.defaultSchedule,
        );
      },
    );
  }

  Future<void> _saveDefaultSchedule() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isSavingSchedule = true;
      });

      final Map<String, List<String>> scheduleToSave = {};
      _scheduleMap.forEach((day, shiftsSet) {
        scheduleToSave[day] = shiftsSet.toList()..sort();
      });

      try {
        await pbService.users.updateStaffDefaultSchedule(
          profileId: widget.profile.id,
          defaultSchedule: scheduleToSave,
        );

        if (mounted) _showSnackbar('Đã lưu lịch cố định!', Colors.green);
      } catch (e) {
        if (mounted) _showSnackbar('Lỗi lưu lịch: $e', Colors.red);
      } finally {
        if (mounted)
          setState(() {
            _isSavingSchedule = false;
          });
      }
    }
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  void _toggleShift(String day, String shift, bool? isSelected) {
    setState(() {
      if (isSelected == true) {
        _scheduleMap[day]!.add(shift);
      } else {
        _scheduleMap[day]!.remove(shift);
      }
    });
  }

  void _toggleAllShiftsForDay(String day, bool? isSelected) {
    setState(() {
      if (isSelected == true) {
        _scheduleMap[day] = Set<String>.from(_allShifts);
      } else {
        _scheduleMap[day] = <String>{};
      }
    });
  }

  bool? _getSelectAllStateForDay(String day) {
    final shiftsForDay = _scheduleMap[day]!;
    if (shiftsForDay.isEmpty) {
      return false;
    }
    if (shiftsForDay.length == _allShifts.length) {
      return true;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Lịch: ${widget.profile.name}'),
          backgroundColor: Colors.teal.shade600,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Lịch Cố Định', icon: Icon(Icons.event_repeat)),
              Tab(text: 'Ngoại Lệ (Nghỉ/Thêm)', icon: Icon(Icons.event_busy)),
            ],
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.yellow,
          ),
        ),
        body: TabBarView(
          children: [_buildDefaultScheduleTab(), _buildExceptionsTab()],
        ),
      ),
    );
  }

  Widget _buildDefaultScheduleTab() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Table(
                  border: TableBorder(
                    horizontalInside: BorderSide(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                    verticalInside: BorderSide(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  columnWidths: const {
                    0: FixedColumnWidth(110),
                    1: FixedColumnWidth(80),
                    2: FixedColumnWidth(80),
                    3: FixedColumnWidth(80),
                  },
                  children: [
                    _buildHeaderRow(),
                    ..._allWorkDays.map((day) {
                      return _buildDayScheduleRow(day);
                    }),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              icon: _isSavingSchedule
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(
                _isSavingSchedule ? 'Đang lưu...' : 'Lưu Lịch Cố Định',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: _isSavingSchedule ? null : _saveDefaultSchedule,
            ),
          ),
        ],
      ),
    );
  }

  TableRow _buildHeaderRow() {
    final headerStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 13);
    return TableRow(
      decoration: BoxDecoration(color: Colors.grey.shade200),
      children: [
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text('Ngày', style: headerStyle),
            ),
          ),
        ),
        ..._allShifts.map((shift) {
          String shortShift = shift.replaceAll('Ca ', '');
          return TableCell(
            verticalAlignment: TableCellVerticalAlignment.middle,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 22.0),
                child: Text(shortShift, style: headerStyle),
              ),
            ),
          );
        }),
      ],
    );
  }

  TableRow _buildDayScheduleRow(String day) {
    bool? selectAllState = _getSelectAllStateForDay(day);

    return TableRow(
      children: [
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                day,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Checkbox(
                value: selectAllState,
                tristate: true,
                onChanged: (bool? val) {
                  _toggleAllShiftsForDay(day, val);
                },
                activeColor: Colors.teal,
              ),
            ],
          ),
        ),
        ..._allShifts.map((shift) {
          final isSelected = _scheduleMap[day]!.contains(shift);
          return TableCell(
            verticalAlignment: TableCellVerticalAlignment.middle,
            child: Center(
              child: Checkbox(
                value: isSelected,
                onChanged: (bool? val) {
                  _toggleShift(day, shift, val);
                },
                activeColor: Colors.teal,
              ),
            ),
          );
        }),
      ],
    );
  }

  // --- ĐÃ CẬP NHẬT ĐỂ HIỂN THỊ ĐÚNG LOẠI + TIỀN PHẠT + THƯỞNG ---
  Widget _buildExceptionsTab() {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadExceptions,
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
            if (exceptions.isEmpty) {
              return Stack(
                children: [
                  ListView(),
                  Center(
                    child: Text(
                      'Không có ngoại lệ nào.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              itemCount: exceptions.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final ex = exceptions[index];

                // Xác định Icon, Màu sắc và Tiêu đề
                IconData icon;
                Color color;
                String titleText = ex.type.display;

                switch (ex.type) {
                  case ScheduleExceptionType.extraShift:
                    icon = Icons.more_time;
                    color = Colors.blue;
                    titleText += ": ${ex.shift ?? 'N/A'}";
                    break;
                  case ScheduleExceptionType.absent:
                    icon = Icons.beach_access;
                    color = Colors.orange;
                    break;
                  case ScheduleExceptionType.late:
                    icon = Icons.timer_off;
                    color = Colors.amber.shade800; // Màu cam đậm cảnh báo
                    break;
                  case ScheduleExceptionType.unexcused:
                    icon = Icons.block; // Icon cấm
                    color = Colors.red;
                    break;
                }

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withOpacity(0.1),
                    child: Icon(icon, color: color),
                  ),
                  title: Text(
                    titleText,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        DateFormat('EEEE, dd/MM/yyyy', 'vi_VN').format(ex.date),
                      ),
                      if (ex.penalty > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(
                            "-${formatCurrency(ex.penalty)}",
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      if (ex.bonus > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Text(
                            "+${formatCurrency(ex.bonus)}",
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _handleDeleteException(ex.id),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
