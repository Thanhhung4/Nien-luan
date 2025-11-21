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
  final List<ScheduleExceptionModel>
  existingExceptions; // <-- Nhận danh sách cũ để check

  const AddExceptionDialog({
    super.key,
    required this.onSave,
    required this.initialDate,
    required this.defaultSchedule,
    required this.existingExceptions, // <-- Bắt buộc
  });

  @override
  State<AddExceptionDialog> createState() => _AddExceptionDialogState();
}

class _AddExceptionDialogState extends State<AddExceptionDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late DateTime _selectedDate;
  ScheduleExceptionType _selectedType = ScheduleExceptionType.absent;
  final Set<String> _selectedShifts = {};

  final _penaltyController = TextEditingController(text: '0');
  final _bonusController = TextEditingController(text: '0');
  final _dateController = TextEditingController();

  final List<String> _shiftOptions = ['Ca sáng', 'Ca chiều', 'Ca tối'];
  static const double _bonusPerShift = 100000;
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
    // Tìm ngày hợp lệ
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

  // --- LOGIC KIỂM TRA ---
  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<String> _getScheduledShifts(DateTime day) {
    final weekdayKey = _weekdayMap[day.weekday];
    return widget.defaultSchedule[weekdayKey] ?? [];
  }

  bool _hasWorkSchedule(DateTime day) => _getScheduledShifts(day).isNotEmpty;
  bool _isDayFullyBooked(DateTime day) =>
      _getScheduledShifts(day).length >= _shiftOptions.length;

  bool _selectableDayPredicate(DateTime day) {
    if (_selectedType == ScheduleExceptionType.extraShift) return true;
    return _hasWorkSchedule(day);
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

  List<String> _getAvailableShiftsForExtra(DateTime day) {
    final scheduled = _getScheduledShifts(day);
    return _shiftOptions.where((s) => !scheduled.contains(s)).toList();
  }

  void _calculateBonus() {
    if (_selectedType == ScheduleExceptionType.extraShift) {
      double total = _selectedShifts.length * _bonusPerShift;
      _bonusController.text = total.toStringAsFixed(0);
    } else {
      _bonusController.text = '0';
    }
  }

  void _updateDefaultValues(ScheduleExceptionType type) {
    if (type == ScheduleExceptionType.late) {
      _penaltyController.text = '50000';
      _bonusController.text = '0';
    } else if (type == ScheduleExceptionType.unexcused) {
      _penaltyController.text = '200000';
      _bonusController.text = '0';
    } else if (type == ScheduleExceptionType.extraShift) {
      _penaltyController.text = '0';
      _calculateBonus();
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
        _selectedShifts.clear();
        _calculateBonus();
        _updateDateText();
      });
    }
  }

  // --- HÀM KIỂM TRA RÀNG BUỘC (QUAN TRỌNG) ---
  String? _validateRules() {
    // Lấy danh sách ngoại lệ ĐÃ CÓ trong ngày được chọn
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
    if ((_selectedType == ScheduleExceptionType.absent ||
            _selectedType == ScheduleExceptionType.unexcused ||
            _selectedType == ScheduleExceptionType.late) &&
        hasExtra) {
      return "Ngày này đã có lịch làm thêm, không thể báo nghỉ/trễ.";
    }

    // Rule 2: Không thêm Làm thêm nếu đã Nghỉ (Có phép hoặc Không phép)
    if (_selectedType == ScheduleExceptionType.extraShift &&
        (hasAbsent || hasUnexcused)) {
      return "Nhân viên đã báo nghỉ ngày này, không thể làm thêm.";
    }

    // Rule 3: Không thêm Làm thêm nếu đã Đi trễ VÀ Ngày đó đã Kín lịch
    // (Logic: Trễ + Full lịch = Phạt nặng, ko làm thêm. Trễ + Còn trống -> Cho làm bù)
    if (_selectedType == ScheduleExceptionType.extraShift &&
        hasLate &&
        _isDayFullyBooked(_selectedDate)) {
      return "Ngày đã kín lịch và nhân viên đi trễ, không thể làm thêm.";
    }

    // Rule 4: Không được cùng ngày có 2 ngoại lệ loại (Nghỉ/Trễ)
    if (_selectedType == ScheduleExceptionType.absent ||
        _selectedType == ScheduleExceptionType.unexcused ||
        _selectedType == ScheduleExceptionType.late) {
      if (existingOnDate.any(
        (e) =>
            e.type == ScheduleExceptionType.absent ||
            e.type == ScheduleExceptionType.unexcused ||
            e.type == ScheduleExceptionType.late,
      )) {
        return "Ngày này đã có ghi nhận nghỉ hoặc đi trễ rồi.";
      }
    }

    // Rule 5: Kiểm tra trùng ca làm thêm
    if (_selectedType == ScheduleExceptionType.extraShift) {
      // Lấy các ca làm thêm ĐÃ CÓ trong ngày
      final existingExtraShifts = existingOnDate
          .where(
            (e) =>
                e.type == ScheduleExceptionType.extraShift && e.shift != null,
          )
          .expand((e) => e.shift!.split(', '))
          .toSet();

      // Kiểm tra xem ca MỚI CHỌN có trùng với ca ĐÃ CÓ không
      for (var shift in _selectedShifts) {
        if (existingExtraShifts.contains(shift)) {
          return "Ca '$shift' đã được đăng ký làm thêm rồi.";
        }
      }
    }

    return null; // Không có lỗi
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() ?? false) {
      // 1. Validate các lỗi logic ngày tháng thông thường
      if (_selectedType == ScheduleExceptionType.extraShift) {
        if (_selectedShifts.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vui lòng chọn ít nhất 1 ca làm thêm'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      } else {
        if (!_hasWorkSchedule(_selectedDate)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ngày này không có lịch làm.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      // 2. Validate các RULE PHỨC TẠP (MỚI)
      final errorMsg = _validateRules();
      if (errorMsg != null) {
        // Hiển thị Dialog cảnh báo lỗi thay vì Snackbar để người dùng đọc kỹ
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
        final sortedShifts = _selectedShifts.toList()
          ..sort(
            (a, b) =>
                _shiftOptions.indexOf(a).compareTo(_shiftOptions.indexOf(b)),
          );
        final shiftString = sortedShifts.join(', ');

        await widget.onSave(
          date: _selectedDate,
          type: _selectedType,
          shift: _selectedType == ScheduleExceptionType.extraShift
              ? shiftString
              : null,
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
    if (isExtra) {
      if (_isDayFullyBooked(_selectedDate)) {
        // Chỉ báo lỗi nếu ĐÃ FULL và KHÔNG CÓ Late (theo rule bổ sung thì Late + còn chỗ vẫn được làm)
        // Nhưng ở đây chỉ cảnh báo UI, logic chính nằm ở _submit
        isDateError = true;
        dateErrorText = "Ngày này đã kín lịch (3 ca).";
      }
    } else {
      if (!_hasWorkSchedule(_selectedDate)) {
        isDateError = true;
        dateErrorText = "Ngày này không có lịch làm việc.";
      }
    }

    final availableShiftsForDate = isExtra
        ? _getAvailableShiftsForExtra(_selectedDate)
        : <String>[];

    return AlertDialog(
      title: const Text('Thêm Ngoại lệ'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                items: ScheduleExceptionType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.display),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedType = value;
                      _selectedShifts.clear();
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
              if (isExtra) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    availableShiftsForDate.isEmpty
                        ? "Không có ca trống"
                        : "Chọn ca làm thêm (còn trống):",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: availableShiftsForDate.isEmpty
                          ? Colors.grey
                          : Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (availableShiftsForDate.isNotEmpty)
                  Wrap(
                    spacing: 8.0,
                    children: availableShiftsForDate.map((shift) {
                      final isSelected = _selectedShifts.contains(shift);
                      return FilterChip(
                        label: Text(shift),
                        selected: isSelected,
                        selectedColor: Colors.green.shade100,
                        checkmarkColor: Colors.green,
                        onSelected: (bool selected) {
                          setState(() {
                            if (selected)
                              _selectedShifts.add(shift);
                            else
                              _selectedShifts.remove(shift);
                            _calculateBonus();
                          });
                        },
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 16),
              ],
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
