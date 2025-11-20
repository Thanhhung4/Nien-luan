// [DÁN TOÀN BỘ CODE NÀY VÀO lib/screens/manager/staff_schedule_detail_screen.dart]

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:myshop/models/schedule_exception.dart';
import 'package:myshop/models/staff_profile.dart';
import 'package:myshop/services/pocketbase_service.dart';
import 'package:myshop/widgets/manager/add_exception_dialog.dart';

// Định nghĩa các hằng số cho form
const List<String> _allWorkDays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
const List<String> _allShifts = ['Ca sáng', 'Ca chiều', 'Ca tối'];
// const List<String> _allWorkTypes = ['full_time', 'part_time']; // <-- ĐÃ XÓA

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
  final DateTime _startDate = DateTime.now();
  final DateTime _endDate = DateTime.now().add(const Duration(days: 30));

  // State cho Tab Lịch Cố Định
  final _formKey = GlobalKey<FormState>();
  // late String _selectedWorkType; // <-- ĐÃ XÓA
  late Map<String, Set<String>> _scheduleMap;
  bool _isSavingSchedule = false;

  @override
  void initState() {
    super.initState();
    // Khởi tạo Tab Ngoại Lệ
    _loadExceptions();

    // Khởi tạo Tab Lịch Cố Định
    // _selectedWorkType = widget.profile.workType; // <-- ĐÃ XÓA

    _scheduleMap = {};
    for (var day in _allWorkDays) {
      final shiftsForDay = widget.profile.defaultSchedule[day] ?? [];
      _scheduleMap[day] = Set<String>.from(shiftsForDay);
    }
  }

  // --- LOGIC CHO TAB NGOẠI LỆ (Giữ nguyên) ---
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

  Future<void> _handleCreateException({
    required DateTime date,
    required ScheduleExceptionType type,
    String? shift,
  }) async {
    try {
      await pbService.schedules.createScheduleException(
        staffProfileId: widget.profile.id,
        date: date,
        type: type,
        shift: shift,
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
        );
      },
    );
  }
  // --- KẾT THÚC LOGIC TAB NGOẠI LỆ ---

  // --- LOGIC CHO TAB LỊCH CỐ ĐỊNH (SỬA LỖI KHÔNG LƯU) ---
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
        // --- SỬA Ở ĐÂY (Đã xóa workType) ---
        await pbService.users.updateStaffDefaultSchedule(
          profileId: widget.profile.id,
          defaultSchedule: scheduleToSave, // Gửi Map mới
        );
        // --- KẾT THÚC SỬA ---

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

  // Hàm xử lý khi bấm vào 1 ô Checkbox lẻ
  void _toggleShift(String day, String shift, bool? isSelected) {
    setState(() {
      if (isSelected == true) {
        _scheduleMap[day]!.add(shift);
      } else {
        _scheduleMap[day]!.remove(shift);
      }
    });
  }

  // Hàm xử lý khi bấm "chọn tất cả" THEO NGÀY (Hàng)
  void _toggleAllShiftsForDay(String day, bool? isSelected) {
    setState(() {
      if (isSelected == true) {
        _scheduleMap[day] = Set<String>.from(_allShifts);
      } else {
        _scheduleMap[day] = <String>{};
      }
    });
  }

  // Hàm kiểm tra trạng thái Checkbox "chọn tất cả" THEO NGÀY (Hàng)
  bool? _getSelectAllStateForDay(String day) {
    final shiftsForDay = _scheduleMap[day]!;
    if (shiftsForDay.isEmpty) {
      return false;
    }
    if (shiftsForDay.length == _allShifts.length) {
      return true;
    }
    return null; // Tristate (dấu gạch ngang)
  }
  // --- KẾT THÚC LOGIC TAB LỊCH CỐ ĐỊNH ---

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

  // --- WIDGET CHO TAB 1: LỊCH CỐ ĐỊNH (Giao diện tối ưu đã xóa workType) ---
  Widget _buildDefaultScheduleTab() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // 1. Bảng Lịch (Grid)
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal, // Cho phép cuộn ngang
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
                  // Đặt độ rộng cố định
                  columnWidths: const {
                    0: FixedColumnWidth(110), // Cột Ngày (Rộng hơn)
                    1: FixedColumnWidth(80), // Cột Sáng
                    2: FixedColumnWidth(80), // Cột Chiều
                    3: FixedColumnWidth(80), // Cột Tối
                  },
                  children: [
                    _buildHeaderRow(), // Dòng tiêu đề
                    ..._allWorkDays.map((day) {
                      // Dòng cho mỗi ngày
                      return _buildDayScheduleRow(day);
                    }),
                  ],
                ),
              ),
            ),
          ),

          // 2. Nút Lưu
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

  // Widget con: Dòng Tiêu đề (Ca Sáng, Chiều, Tối)
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

  // Widget con: Dòng cho mỗi ngày (T2, T3, T4...)
  TableRow _buildDayScheduleRow(String day) {
    bool? selectAllState = _getSelectAllStateForDay(day);

    return TableRow(
      children: [
        // Tên Ngày VÀ Checkbox "chọn tất cả"
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

        // 3 ô Checkbox lẻ
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

  // --- WIDGET CHO TAB 2: NGOẠI LỆ (Giữ nguyên) ---
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
                      'Không có ngoại lệ nào trong 30 ngày tới.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              itemCount: exceptions.length,
              itemBuilder: (context, index) {
                final ex = exceptions[index];
                final isAbsent = ex.type == ScheduleExceptionType.absent;
                return ListTile(
                  leading: Icon(
                    isAbsent ? Icons.beach_access : Icons.add_alarm,
                    color: isAbsent ? Colors.orange : Colors.blue,
                  ),
                  title: Text(
                    isAbsent ? 'Nghỉ' : 'Làm thêm: ${ex.shift ?? 'N/A'}',
                  ),
                  subtitle: Text(
                    DateFormat('EEEE, dd/MM/yyyy', 'vi_VN').format(ex.date),
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
