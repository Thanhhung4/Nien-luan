// [CẬP NHẬT FILE: lib/widgets/manager/add_notification_dialog.dart]

import 'package:flutter/material.dart';
import 'package:myshop/models/notification.dart';

// Đổi tên callback cho tổng quát
typedef OnSaveNotificationCallback =
    Future<void> Function(String title, String content);

class AddNotificationDialog extends StatefulWidget {
  final OnSaveNotificationCallback onSave;
  final NotificationModel? notification; // Nhận vào để sửa

  const AddNotificationDialog({
    super.key,
    required this.onSave,
    this.notification,
  });

  @override
  State<AddNotificationDialog> createState() => _AddNotificationDialogState();
}

class _AddNotificationDialogState extends State<AddNotificationDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Điền dữ liệu cũ nếu đang sửa
    _titleController = TextEditingController(
      text: widget.notification?.title ?? '',
    );
    _contentController = TextEditingController(
      text: widget.notification?.content ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);
      try {
        await widget.onSave(
          _titleController.text.trim(),
          _contentController.text.trim(),
        );
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        if (mounted) {
          // Chỉ tắt loading để màn hình cha hiện snackbar
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.notification != null;

    return AlertDialog(
      title: Text(isEditing ? 'Sửa Thông báo' : 'Gửi Thông báo Mới'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Tiêu đề*',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Vui lòng nhập tiêu đề'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: 'Nội dung*',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Vui lòng nhập nội dung'
                    : null,
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
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEditing ? 'Cập nhật' : 'Gửi'),
        ),
      ],
    );
  }
}
