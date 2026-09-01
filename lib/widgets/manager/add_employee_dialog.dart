// [CẬP NHẬT FILE: lib/widgets/manager/add_employee_dialog.dart]

import 'package:flutter/material.dart';
import 'package:myshop/models/staff_role.dart';

// Callback
typedef OnAddEmployee =
    Future<void> Function({
      required String name,
      required String email,
      required String password,
      required StaffRole role,
      required double salary,
    });

class AddEmployeeDialog extends StatefulWidget {
  final OnAddEmployee onAdd;

  const AddEmployeeDialog({super.key, required this.onAdd});

  @override
  State<AddEmployeeDialog> createState() => _AddEmployeeDialogState();
}

class _AddEmployeeDialogState extends State<AddEmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  StaffRole _selectedRole = StaffRole.employee; // Mặc định là nhân viên

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);
      try {
        // Kiểm tra xem vai trò này có cần login không
        final bool needsAccount = _selectedRole == StaffRole.employee;

        await widget.onAdd(
          name: _nameController.text.trim(),
          // Nếu cần TK thì lấy giá trị nhập, không thì gửi chuỗi rỗng
          email: needsAccount ? _emailController.text.trim() : "",
          password: needsAccount ? _passwordController.text.trim() : "",
          role: _selectedRole,
          salary: 0, // Lương tự động tính sau
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
    // Chỉ Nhân viên (employee) mới cần tài khoản đăng nhập
    // (Dựa trên logic bạn yêu cầu: admin & employee có user, còn lại thì không)
    final bool needsAccount = _selectedRole == StaffRole.employee;

    return AlertDialog(
      title: const Text('Thêm Nhân Viên Mới'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Tên (Luôn bắt buộc)
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Họ và Tên',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Vui lòng nhập tên' : null,
              ),
              const SizedBox(height: 16),

              // 2. Chọn Vai trò (Đưa lên trên để điều khiển hiển thị Email/Pass)
              DropdownButtonFormField<StaffRole>(
                initialValue: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Vai trò / Chức vụ',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.work),
                ),
                items: StaffRole.values.map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Text(role.display),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedRole = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // 3. Email & Mật khẩu (Chỉ hiện nếu là Employee)
              if (needsAccount) ...[
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email đăng nhập',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (!needsAccount) return null;
                    return (v == null || v.isEmpty || !v.contains('@'))
                        ? 'Email không hợp lệ'
                        : null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu',
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (v) {
                    if (!needsAccount) return null;
                    return (v == null || v.length < 6)
                        ? 'Mật khẩu tối thiểu 6 ký tự'
                        : null;
                  },
                ),
                const SizedBox(height: 16),
              ] else ...[
                // Thông báo cho các vai trò không cần đăng nhập
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, size: 20, color: Colors.orange.shade800),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Vai trò '${_selectedRole.display}' chỉ cần lưu hồ sơ chấm công, không cần tạo tài khoản đăng nhập.",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Lương (Thông báo tự động)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.attach_money, size: 16, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Lương sẽ được tính tự động dựa trên Lịch làm việc.",
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
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
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Thêm'),
        ),
      ],
    );
  }
}
