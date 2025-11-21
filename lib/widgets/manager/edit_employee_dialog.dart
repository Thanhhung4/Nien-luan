// [CẬP NHẬT FILE: lib/widgets/manager/edit_employee_dialog.dart]

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:myshop/models/staff_profile.dart';
import 'package:myshop/models/staff_role.dart';
import 'package:myshop/utils/currency_formatter.dart';

// Callback cập nhật
typedef UpdateStaffDetailsCallback =
    Future<void> Function({
      required String profileId,
      required String name,
      required StaffRole role,
      required String status,
      String? userId,
      String? newEmail,
      String? newPassword,
    });

class EditEmployeeDialog extends StatefulWidget {
  final StaffProfile profile;
  final UpdateStaffDetailsCallback onUpdate;

  const EditEmployeeDialog({
    super.key,
    required this.profile,
    required this.onUpdate,
  });

  @override
  State<EditEmployeeDialog> createState() => _EditEmployeeDialogState();
}

class _EditEmployeeDialogState extends State<EditEmployeeDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController nameController;
  late TextEditingController emailController;
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  late StaffRole _selectedRole;
  late String _selectedStatus;
  bool _isLoading = false;

  final List<String> _statusOptions = ['active', 'resigned', 'on_leave'];

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.profile.name);
    emailController = TextEditingController(text: widget.profile.email);

    _selectedRole = widget.profile.role;
    _selectedStatus = widget.profile.status;
    if (!_statusOptions.contains(_selectedStatus)) {
      _selectedStatus = 'active';
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);

      String? newEmail;
      if (widget.profile.hasLoginAccount &&
          emailController.text != widget.profile.email) {
        newEmail = emailController.text;
      }

      String? newPassword;
      if (widget.profile.hasLoginAccount &&
          passwordController.text.isNotEmpty) {
        newPassword = passwordController.text;
      }

      try {
        await widget.onUpdate(
          profileId: widget.profile.id,
          name: nameController.text,
          role: _selectedRole, // Role giữ nguyên
          status: _selectedStatus,
          userId: widget.profile.userId,
          newEmail: newEmail,
          newPassword: newPassword,
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
    return AlertDialog(
      title: Text('Sửa Hồ sơ: ${widget.profile.name}'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // -------- TÊN --------
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Tên đầy đủ*'),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Không được để trống' : null,
              ),
              const SizedBox(height: 10),

              // -------- ROLE (ĐÃ KHÓA) --------
              TextFormField(
                initialValue: _selectedRole.display,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Vai trò (Không thể thay đổi)',
                  prefixIcon: const Icon(Icons.work_outline),
                  border: const OutlineInputBorder(),
                  fillColor: Colors.grey.shade200,
                  filled: true,
                ),
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 10),

              // -------- TRẠNG THÁI --------
              DropdownButtonFormField<String>(
                value: _selectedStatus,
                decoration: const InputDecoration(labelText: 'Trạng thái'),
                items: _statusOptions
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedStatus = val);
                },
              ),
              const SizedBox(height: 10),

              // -------- LƯƠNG CHỈ ĐỌC --------
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Lương cứng (Tự động tính)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
                child: Text(
                  formatCurrency(widget.profile.salary),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),

              // -------- TÀI KHOẢN (Nếu có) --------
              if (widget.profile.hasLoginAccount) ...[
                const Divider(height: 30),
                Text(
                  'Tài khoản đăng nhập',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),

                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email*'),
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Email sai định dạng'
                      : null,
                ),
                const SizedBox(height: 10),

                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Mật khẩu mới (nếu đổi)',
                  ),
                  validator: (v) {
                    if (v != null && v.isNotEmpty && v.length < 8) {
                      return 'Tối thiểu 8 ký tự';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),

                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Xác nhận mật khẩu',
                  ),
                  validator: (v) {
                    if (passwordController.text.isNotEmpty &&
                        v != passwordController.text) {
                      return 'Mật khẩu không khớp';
                    }
                    return null;
                  },
                ),
              ],
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
