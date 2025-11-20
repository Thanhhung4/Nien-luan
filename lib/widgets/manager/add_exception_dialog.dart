import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:myshop/models/schedule_exception.dart';

// Callback function
typedef OnSaveExceptionCallback =
    Future<void> Function({
      required DateTime date,
      required ScheduleExceptionType type,
      String? shift,
    });

class AddExceptionDialog extends StatefulWidget {
  final OnSaveExceptionCallback onSave;
  final DateTime initialDate; // Ngày được chọn

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
  String? _selectedShift; // Chỉ dùng cho 'extraShift'

  final List<String> _shiftOptions = ['Ca sáng', 'Ca chiều', 'Ca tối'];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() ?? false) {
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

      setState(() {
        _isLoading = true;
      });
      try {
        await widget.onSave(
          date: _selectedDate,
          type: _selectedType,
          shift: _selectedType == ScheduleExceptionType.extraShift
              ? _selectedShift
              : null,
        );
        if (mounted) Navigator.of(context).pop(); // Đóng dialog
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
          );
        }
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Thêm Ngoại lệ Lịch'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Chọn ngày
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

            // 2. Chọn loại (Nghỉ / Làm thêm)
            DropdownButtonFormField<ScheduleExceptionType>(
              value: _selectedType,
              decoration: const InputDecoration(labelText: 'Loại*'),
              items: const [
                DropdownMenuItem(
                  value: ScheduleExceptionType.absent,
                  child: Text('Nghỉ phép/Ốm'),
                ),
                DropdownMenuItem(
                  value: ScheduleExceptionType.extraShift,
                  child: Text('Làm thêm ca'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedType = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // 3. Chọn ca (Chỉ hiện khi là 'Làm thêm')
            if (_selectedType == ScheduleExceptionType.extraShift)
              DropdownButtonFormField<String>(
                value: _selectedShift,
                decoration: const InputDecoration(
                  labelText: 'Chọn ca làm thêm*',
                ),
                items: _shiftOptions.map((shift) {
                  return DropdownMenuItem(value: shift, child: Text(shift));
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedShift = value;
                    });
                  }
                },
                validator: (value) =>
                    (value == null &&
                        _selectedType == ScheduleExceptionType.extraShift)
                    ? 'Vui lòng chọn ca'
                    : null,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Lưu'),
        ),
      ],
    );
  }
}
