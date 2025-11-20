import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:myshop/models/staff_profile.dart';
import 'package:myshop/models/staff_role.dart';

// Callback mới (thêm email/password)
typedef UpdateStaffDetailsCallback =
    Future<void> Function({
      required String profileId,
      required String name,
      required StaffRole role,
      required double salary,
      required String status,
      // Thêm thông tin tài khoản (nếu có)
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
  // Controllers cho Profile
  late TextEditingController nameController;
  late TextEditingController salaryController;
  late StaffRole _selectedRole;
  late String _selectedStatus;

  // Controllers cho Account (nếu có)
  late TextEditingController emailController;
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  final List<String> _statusOptions = ['active', 'resigned', 'on_leave'];

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.profile.name);
    salaryController = TextEditingController(
      text: widget.profile.salary.toStringAsFixed(0),
    );
    _selectedRole = widget.profile.role;
    _selectedStatus = widget.profile.status;

    emailController = TextEditingController(text: widget.profile.email);

    if (!_statusOptions.contains(_selectedStatus)) {
      _selectedStatus = 'active';
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    salaryController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });

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
          role: _selectedRole, // Không cho đổi nữa
          salary: double.tryParse(salaryController.text) ?? 0.0,
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
        }
      } finally {
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
      title: Text('Sửa Hồ sơ: ${widget.profile.name}'),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 24.0,
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Thông tin cơ bản',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Tên đầy đủ*'),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Tên không được để trống'
                    : null,
              ),
              const SizedBox(height: 10),

              // Vai trò (chỉ đọc)
              TextFormField(
                readOnly: true,
                initialValue: _selectedRole.display,
                decoration: const InputDecoration(
                  labelText: 'Vai trò',
                  suffixIcon: Icon(Icons.lock, size: 18),
                ),
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: salaryController,
                decoration: const InputDecoration(labelText: 'Lương (VND)'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedStatus,
                decoration: const InputDecoration(labelText: 'Trạng thái*'),
                items: _statusOptions
                    .map(
                      (status) =>
                          DropdownMenuItem(value: status, child: Text(status)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedStatus = value;
                    });
                  }
                },
              ),

              // --- Thông tin Tài khoản ---
              if (widget.profile.hasLoginAccount)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 24),
                    Text(
                      'Thông tin tài khoản (Đăng nhập)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: 'Email*'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) =>
                          (value == null || !value.contains('@'))
                          ? 'Email không hợp lệ'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Đặt lại mật khẩu (để trống nếu không đổi)',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    TextFormField(
                      controller: passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Mật khẩu mới',
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value != null &&
                            value.isNotEmpty &&
                            value.length < 8) {
                          return 'Mật khẩu mới phải ít nhất 8 ký tự';
                        }
                        if (value != confirmPasswordController.text) {
                          return 'Mật khẩu xác nhận không khớp';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: confirmPasswordController,
                      decoration: const InputDecoration(
                        labelText: 'Xác nhận mật khẩu mới',
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (passwordController.text.isNotEmpty &&
                            value != passwordController.text) {
                          return 'Mật khẩu xác nhận không khớp';
                        }
                        return null;
                      },
                    ),
                  ],
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
              : const Text('Lưu'),
        ),
      ],
    );
  }
}
