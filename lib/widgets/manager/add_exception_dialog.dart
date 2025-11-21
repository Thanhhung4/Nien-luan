// [CẬP NHẬT FILE: lib/widgets/manager/add_exception_dialog.dart]

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import này để dùng FilteringTextInputFormatter
import 'package:intl/intl.dart';
import 'package:myshop/models/schedule_exception.dart';
import 'package:myshop/utils/currency_formatter.dart'; // Để format tiền gợi ý

// Callback cập nhật thêm penalty
typedef OnSaveExceptionCallback =
    Future<void> Function({
      required DateTime date,
      required ScheduleExceptionType type,
      String? shift,
      double penalty, // Thêm
    });

class AddExceptionDialog extends StatefulWidget {
  final OnSaveExceptionCallback onSave;
  final DateTime initialDate;

  const AddExceptionDialog({
    super.key,
    required this.onSave,
    required this.initialDate,
  });

  @override
  State<AddExceptionDialog> createState() => _AddExceptionDialogState();
}

class _AddExceptionDialogState extends State<AddExceptionDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late DateTime _selectedDate;
  ScheduleExceptionType _selectedType = ScheduleExceptionType.absent;
  String? _selectedShift;

  // Controller cho tiền phạt
  final _penaltyController = TextEditingController(text: '0');

  final List<String> _shiftOptions = ['Ca sáng', 'Ca chiều', 'Ca tối'];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  // Hàm tự động gợi ý tiền phạt
  void _updateDefaultPenalty(ScheduleExceptionType type) {
    double amount = 0;
    if (type == ScheduleExceptionType.late) amount = 50000; // 50k
    if (type == ScheduleExceptionType.unexcused)
      amount = 200000; // 200k (ví dụ)

    _penaltyController.text = amount.toStringAsFixed(0);
  }

  Future<void> _pickDate() async {
    // ... (Giữ nguyên)
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() ?? false) {
      // Validate Ca làm thêm
      if (_selectedType == ScheduleExceptionType.extraShift &&
          _selectedShift == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng chọn ca làm thêm'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        await widget.onSave(
          date: _selectedDate,
          type: _selectedType,
          shift: _selectedType == ScheduleExceptionType.extraShift
              ? _selectedShift
              : null,
          penalty:
              double.tryParse(_penaltyController.text) ?? 0, // Lấy tiền phạt
        );
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        // ... (Xử lý lỗi giữ nguyên)
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Kiểm tra xem có cần hiện ô nhập tiền phạt không
    final bool showPenaltyInput =
        _selectedType == ScheduleExceptionType.late ||
        _selectedType == ScheduleExceptionType.unexcused;

    return AlertDialog(
      title: const Text('Thêm Ngoại lệ/Vi phạm'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Chọn ngày (Giữ nguyên)
            TextFormField(
              readOnly: true,
              controller: TextEditingController(
                text: DateFormat('dd/MM/yyyy').format(_selectedDate),
              ),
              decoration: const InputDecoration(
                labelText: 'Ngày',
                suffixIcon: Icon(Icons.calendar_month),
              ),
              onTap: _pickDate,
            ),
            const SizedBox(height: 16),

            // 2. Chọn loại (Cập nhật items)
            DropdownButtonFormField<ScheduleExceptionType>(
              value: _selectedType,
              decoration: const InputDecoration(labelText: 'Loại*'),
              items: ScheduleExceptionType.values.map((type) {
                return DropdownMenuItem(value: type, child: Text(type.display));
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedType = value;
                    _updateDefaultPenalty(value); // Gợi ý tiền
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // 3. Chọn ca (Chỉ hiện khi Làm thêm)
            if (_selectedType == ScheduleExceptionType.extraShift)
              DropdownButtonFormField<String>(
                value: _selectedShift,
                decoration: const InputDecoration(
                  labelText: 'Chọn ca làm thêm*',
                ),
                items: _shiftOptions
                    .map(
                      (shift) =>
                          DropdownMenuItem(value: shift, child: Text(shift)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _selectedShift = value),
              ),

            // 4. Nhập tiền phạt (Chỉ hiện khi Đi trễ/Nghỉ không phép)
            if (showPenaltyInput)
              TextFormField(
                controller: _penaltyController,
                decoration: const InputDecoration(
                  labelText: 'Số tiền trừ (VND)',
                  suffixText: 'VND',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
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
