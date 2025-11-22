// [CẬP NHẬT FILE: lib/widgets/manager/add_exception_dialog.dart]

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:myshop/models/schedule_exception.dart';

typedef OnSaveExceptionCallback =
    Future<void> Function({
      required DateTime date,
      required ScheduleExceptionType type,
      String? shift,
      double penalty,
      double bonus,
    });

class AddExceptionDialog extends StatefulWidget {
  final OnSaveExceptionCallback onSave;
  final DateTime initialDate;
  final Map<String, List<String>> defaultSchedule;
  final List<ScheduleExceptionModel> existingExceptions;

  const AddExceptionDialog({
    super.key,
    required this.onSave,
    required this.initialDate,
    required this.defaultSchedule,
    required this.existingExceptions,
  });

  @override
  State<AddExceptionDialog> createState() => _AddExceptionDialogState();
}

class _AddExceptionDialogState extends State<AddExceptionDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late DateTime _selectedDate;
  ScheduleExceptionType _selectedType = ScheduleExceptionType.absent;

  // Set lưu các ca được chọn (Dùng chung cho cả Làm thêm và Nghỉ/Trễ)
  final Set<String> _selectedShifts = {};

  final _penaltyController = TextEditingController(text: '0');
  final _bonusController = TextEditingController(text: '0');
  final _dateController = TextEditingController();

  // Danh sách tất cả các ca
  final List<String> _allShiftOptions = ['Ca sáng', 'Ca chiều', 'Ca tối'];
  static const double _bonusPerShift = 100000;
  // Mặc định phạt 50k nếu trễ (có thể sửa lại logic này nếu muốn tự nhân theo ca)
  static const double _penaltyPerShift = 50000;

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
    _selectedDate = widget.initialDate;

    // Tìm ngày hợp lệ ngay khi mở dialog
    if (!_selectableDayPredicate(_selectedDate)) {
      _selectedDate = _findNearestValidDate(widget.initialDate);
    }
    _updateDateText();
  }

  @override
  void dispose() {
    _penaltyController.dispose();
    _bonusController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _updateDateText() {
    _dateController.text = DateFormat(
      'EEEE, dd/MM/yyyy',
      'vi_VN',
    ).format(_selectedDate);
  }

  // --- LOGIC HỖ TRỢ ---
  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // Lấy danh sách ca ĐÃ CÓ LỊCH trong ngày
  List<String> _getScheduledShifts(DateTime day) {
    final weekdayKey = _weekdayMap[day.weekday];
    return widget.defaultSchedule[weekdayKey] ?? [];
  }

  bool _hasWorkSchedule(DateTime day) {
    return _getScheduledShifts(day).isNotEmpty;
  }

  bool _isDayFullyBooked(DateTime day) {
    final scheduled = _getScheduledShifts(day);
    return scheduled.length >= _allShiftOptions.length;
  }

  // --- LOGIC CHẶN NGÀY ---
  bool _selectableDayPredicate(DateTime day) {
    if (_selectedType == ScheduleExceptionType.extraShift) {
      // Làm thêm: Được chọn nếu ngày đó chưa full lịch
      return !_isDayFullyBooked(day);
    }
    // Nghỉ/Trễ: Phải chọn ngày CÓ LỊCH làm việc
    return _hasWorkSchedule(day);
  }

  // --- LOGIC LẤY CA KHẢ DỤNG ---
  List<String> _getAvailableShifts(DateTime day) {
    final scheduled = _getScheduledShifts(day);

    if (_selectedType == ScheduleExceptionType.extraShift) {
      // Làm thêm: Chỉ hiện các ca CHƯA có trong lịch
      return _allShiftOptions.where((s) => !scheduled.contains(s)).toList();
    } else {
      // Nghỉ/Trễ: Chỉ hiện các ca ĐÃ có trong lịch (để báo nghỉ/trễ ca đó)
      return scheduled;
    }
  }

  DateTime _findNearestValidDate(DateTime start) {
    for (int i = 0; i < 30; i++) {
      final date = start.add(Duration(days: i));
      if (_selectableDayPredicate(date)) return date;
    }
    for (int i = 1; i < 30; i++) {
      final date = start.subtract(Duration(days: i));
      if (_selectableDayPredicate(date)) return date;
    }
    return start;
  }

  void _updateDefaultValues(ScheduleExceptionType type) {
    _selectedShifts.clear(); // Reset ca đã chọn khi đổi loại
    _calculateMoney(); // Reset tiền
  }

  // Tự động tính tiền (Lương thêm hoặc Phạt gợi ý)
  void _calculateMoney() {
    int shiftCount = _selectedShifts.length;

    if (_selectedType == ScheduleExceptionType.extraShift) {
      double total = shiftCount * _bonusPerShift;
      _bonusController.text = total.toStringAsFixed(0);
      _penaltyController.text = '0';
    } else if (_selectedType == ScheduleExceptionType.late) {
      // Ví dụ: Trễ mỗi ca phạt 50k (hoặc giữ cố định tùy bạn)
      double total = shiftCount * 50000;
      _penaltyController.text = total.toStringAsFixed(0);
      _bonusController.text = '0';
    } else if (_selectedType == ScheduleExceptionType.unexcused) {
      // Ví dụ: Nghỉ không phép mỗi ca phạt 200k
      double total = shiftCount * 200000;
      _penaltyController.text = total.toStringAsFixed(0);
      _bonusController.text = '0';
    } else {
      _penaltyController.text = '0';
      _bonusController.text = '0';
    }
  }

  Future<void> _pickDate() async {
    final initialPickerDate = _selectableDayPredicate(_selectedDate)
        ? _selectedDate
        : _findNearestValidDate(DateTime.now());

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialPickerDate,
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      selectableDayPredicate: _selectableDayPredicate,
      locale: const Locale('vi', 'VN'),
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
        _selectedShifts.clear(); // Reset ca khi đổi ngày
        _calculateMoney();
        _updateDateText();
      });
    }
  }

  // --- VALIDATE RULE PHỨC TẠP ---
  String? _validateRules() {
    final existingOnDate = widget.existingExceptions
        .where((e) => _isSameDay(e.date, _selectedDate))
        .toList();

    bool hasAbsent = existingOnDate.any(
      (e) => e.type == ScheduleExceptionType.absent,
    );
    bool hasUnexcused = existingOnDate.any(
      (e) => e.type == ScheduleExceptionType.unexcused,
    );
    bool hasLate = existingOnDate.any(
      (e) => e.type == ScheduleExceptionType.late,
    );
    bool hasExtra = existingOnDate.any(
      (e) => e.type == ScheduleExceptionType.extraShift,
    );

    // Rule 1: Không thêm Nghỉ/Trễ nếu đã có Làm thêm
    if ((_selectedType != ScheduleExceptionType.extraShift) && hasExtra) {
      return "Ngày này đã có lịch làm thêm, không thể báo nghỉ/trễ.";
    }

    // Rule 2: Không thêm Làm thêm nếu đã Nghỉ
    if (_selectedType == ScheduleExceptionType.extraShift &&
        (hasAbsent || hasUnexcused)) {
      return "Nhân viên đã báo nghỉ ngày này, không thể làm thêm.";
    }

    // Rule 3: Không thêm Làm thêm nếu đã Đi trễ VÀ Ngày đó đã Kín lịch
    if (_selectedType == ScheduleExceptionType.extraShift &&
        hasLate &&
        _isDayFullyBooked(_selectedDate)) {
      return "Ngày đã kín lịch và có báo trễ, không thể thêm ca làm thêm.";
    }

    // Rule 4: Kiểm tra trùng ca
    // Lấy tất cả các ca đã được ghi nhận trong ngày (từ tất cả các loại exception)
    final Set<String> takenShifts = {};
    for (var e in existingOnDate) {
      if (e.shift != null) {
        takenShifts.addAll(e.shift!.split(', '));
      }
    }

    // Nếu loại mới là Nghỉ/Trễ, cũng cần check xem ca đó đã báo nghỉ/trễ/làm thêm chưa
    for (var shift in _selectedShifts) {
      if (takenShifts.contains(shift)) {
        return "Ca '$shift' đã được ghi nhận trong một ngoại lệ khác rồi.";
      }
    }

    return null;
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() ?? false) {
      // Validate cơ bản
      if (!_selectableDayPredicate(_selectedDate)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ngày đã chọn không hợp lệ.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (_selectedShifts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng chọn ít nhất 1 ca'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Validate Rules phức tạp
      final errorMsg = _validateRules();
      if (errorMsg != null) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Không thể lưu"),
            content: Text(errorMsg),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("OK"),
              ),
            ],
          ),
        );
        return;
      }

      setState(() => _isLoading = true);
      try {
        // Sắp xếp ca cho đẹp
        final sortedShifts = _selectedShifts.toList()
          ..sort(
            (a, b) => _allShiftOptions
                .indexOf(a)
                .compareTo(_allShiftOptions.indexOf(b)),
          );
        final shiftString = sortedShifts.join(', ');

        await widget.onSave(
          date: _selectedDate,
          type: _selectedType,
          shift: shiftString, // Lưu chuỗi ca (cho cả Làm thêm và Nghỉ/Trễ)
          penalty: double.tryParse(_penaltyController.text) ?? 0,
          bonus: double.tryParse(_bonusController.text) ?? 0,
        );
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isPunishment =
        _selectedType == ScheduleExceptionType.late ||
        _selectedType == ScheduleExceptionType.unexcused;
    final bool isExtra = _selectedType == ScheduleExceptionType.extraShift;

    bool isDateError = false;
    String? dateErrorText;

    // Logic báo lỗi UI
    if (isExtra) {
      if (_isDayFullyBooked(_selectedDate)) {
        isDateError = true;
        dateErrorText = "Ngày này đã kín lịch (3 ca).";
      }
    } else {
      if (!_hasWorkSchedule(_selectedDate)) {
        isDateError = true;
        dateErrorText = "Ngày này không có lịch làm việc.";
      }
    }

    // Lấy danh sách ca phù hợp để hiển thị
    final availableShiftsToSelect = _getAvailableShifts(_selectedDate);

    // Tiêu đề cho phần chọn ca
    String selectShiftLabel;
    if (isExtra) {
      selectShiftLabel = "Chọn ca làm thêm:";
    } else if (_selectedType == ScheduleExceptionType.late) {
      selectShiftLabel = "Chọn ca đi trễ:";
    } else {
      selectShiftLabel = "Chọn ca nghỉ:";
    }

    return AlertDialog(
      title: const Text('Thêm Ngoại lệ'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Loại ngoại lệ
              DropdownButtonFormField<ScheduleExceptionType>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Loại ngoại lệ',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                ),
                items: ScheduleExceptionType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.display),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedType = value;
                      _updateDefaultValues(value);
                      if (!_selectableDayPredicate(_selectedDate)) {
                        _selectedDate = _findNearestValidDate(DateTime.now());
                        _updateDateText();
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // 2. Chọn ngày
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Ngày áp dụng',
                    prefixIcon: const Icon(Icons.calendar_month),
                    border: const OutlineInputBorder(),
                    errorText: isDateError ? dateErrorText : null,
                  ),
                  child: Text(
                    _dateController.text,
                    style: TextStyle(
                      color: isDateError ? Colors.red : Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 3. CHỌN CA (ÁP DỤNG CHO TẤT CẢ LOẠI)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  availableShiftsToSelect.isEmpty
                      ? (isExtra
                            ? "Không có ca trống để làm thêm"
                            : "Không có ca làm việc để báo nghỉ/trễ")
                      : selectShiftLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: availableShiftsToSelect.isEmpty
                        ? Colors.red
                        : Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              if (availableShiftsToSelect.isNotEmpty)
                Wrap(
                  spacing: 8.0,
                  children: availableShiftsToSelect.map((shift) {
                    final isSelected = _selectedShifts.contains(shift);
                    return FilterChip(
                      label: Text(shift),
                      selected: isSelected,
                      selectedColor: isExtra
                          ? Colors.green.shade100
                          : Colors.orange.shade100,
                      checkmarkColor: isExtra ? Colors.green : Colors.orange,
                      onSelected: (bool selected) {
                        setState(() {
                          if (selected) {
                            _selectedShifts.add(shift);
                          } else {
                            _selectedShifts.remove(shift);
                          }
                          _calculateMoney();
                        });
                      },
                    );
                  }).toList(),
                ),
              const SizedBox(height: 16),

              // 4. Tiền Phạt
              if (isPunishment)
                TextFormField(
                  controller: _penaltyController,
                  decoration: const InputDecoration(
                    labelText: 'Tiền phạt',
                    suffixText: 'VND',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.money_off, color: Colors.red),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),

              // 5. Tiền Lương thêm
              if (isExtra)
                TextFormField(
                  controller: _bonusController,
                  decoration: const InputDecoration(
                    labelText: 'Tiền lương làm thêm',
                    suffixText: 'VND',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attach_money, color: Colors.green),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}
