import 'package:flutter/material.dart';
import 'package:myshop/models/staff_profile.dart'; // <-- IMPORT MỚI
import 'package:myshop/services/pocketbase_service.dart';

class EditProfileScreen extends StatefulWidget {
  final StaffProfile profile; // <-- Đổi thành StaffProfile

  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final pbService = PocketBaseService.instance;

  // Controllers
  late TextEditingController nameController;
  final oldPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmNewPasswordController = TextEditingController();
  bool _isLoading = false;

  // Trạng thái ẩn/hiện mật khẩu
  bool _obscureOldPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.profile.name);
  }

  @override
  void dispose() {
    nameController.dispose();
    oldPasswordController.dispose();
    newPasswordController.dispose();
    confirmNewPasswordController.dispose();
    super.dispose();
  }

  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  // Xử lý Submit
  Future<void> _submit() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });

      // Lấy giá trị
      final String? newName =
          (nameController.text != widget.profile.name &&
              nameController.text.isNotEmpty)
          ? nameController.text
          : null;
      final String? oldPassword = oldPasswordController.text.isNotEmpty
          ? oldPasswordController.text
          : null;
      final String? newPassword = newPasswordController.text.isNotEmpty
          ? newPasswordController.text
          : null;
      final String? confirmNewPassword =
          confirmNewPasswordController.text.isNotEmpty
          ? confirmNewPasswordController.text
          : null;

      // --- Kiểm tra logic mật khẩu ---
      if (newPassword != null || confirmNewPassword != null) {
        if (oldPassword == null) {
          _showErrorSnackbar(
            'Vui lòng nhập mật khẩu cũ của bạn để đổi mật khẩu.',
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
        if (newPassword == null || newPassword.length < 8) {
          _showErrorSnackbar('Mật khẩu mới phải có ít nhất 8 ký tự.');
          setState(() {
            _isLoading = false;
          });
          return;
        }
        if (newPassword != confirmNewPassword) {
          _showErrorSnackbar('Mật khẩu mới và xác nhận không khớp.');
          setState(() {
            _isLoading = false;
          });
          return;
        }
      } else if (oldPassword != null) {
        _showErrorSnackbar('Vui lòng nhập Mật khẩu mới và Xác nhận.');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      if (newName == null && newPassword == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không có thay đổi nào được thực hiện.'),
          ),
        );
        Navigator.of(context).pop();
        return;
      }

      // --- Bắt đầu gọi Service ---
      try {
        // Tách logic: Cập nhật Tên
        if (newName != null) {
          await pbService.users.updateUserAndProfileName(
            userId: widget.profile.userId!,
            profileId: widget.profile.id,
            newName: newName,
          );
        }

        // Cập nhật Mật khẩu
        if (newPassword != null) {
          await pbService.users.updateUserPassword(
            userId: widget.profile.userId!,
            oldPassword: oldPassword!,
            newPassword: newPassword,
            newPasswordConfirm: confirmNewPassword!,
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cập nhật thông tin thành công!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true); // Trả về true để báo reload
        }
      } catch (e) {
        if (mounted) {
          _showErrorSnackbar('Lỗi cập nhật: $e');
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chỉnh sửa Thông tin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _submit,
            tooltip: 'Lưu',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Email (Không thể đổi):',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                    SelectableText(
                      widget.profile.email, // Lấy email từ profile
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Tên đầy đủ',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value != null && value.length > 50) {
                          return 'Tên không được quá 50 ký tự';
                        }
                        return null;
                      },
                    ),

                    const Divider(height: 30, thickness: 1.5),

                    Text(
                      'Đổi Mật khẩu:',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '(Để trống nếu không muốn đổi)',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 15),

                    // (Các TextFormField Mật khẩu giữ nguyên)
                    TextFormField(
                      controller: oldPasswordController,
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu CŨ CỦA BẠN*',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock_person),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureOldPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setState(
                            () => _obscureOldPassword = !_obscureOldPassword,
                          ),
                        ),
                      ),
                      obscureText: _obscureOldPassword,
                      validator: (value) {
                        if (newPasswordController.text.isNotEmpty &&
                            (value == null || value.isEmpty)) {
                          return 'Nhập mật khẩu cũ để xác thực';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: newPasswordController,
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu Mới*',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureNewPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setState(
                            () => _obscureNewPassword = !_obscureNewPassword,
                          ),
                        ),
                      ),
                      obscureText: _obscureNewPassword,
                      validator: (value) {
                        if (value != null &&
                            value.isNotEmpty &&
                            value.length < 8) {
                          return 'Ít nhất 8 ký tự';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: confirmNewPasswordController,
                      decoration: InputDecoration(
                        labelText: 'Xác nhận Mật khẩu*',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock_reset),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setState(
                            () => _obscureConfirmPassword =
                                !_obscureConfirmPassword,
                          ),
                        ),
                      ),
                      obscureText: _obscureConfirmPassword,
                      validator: (value) {
                        if (newPasswordController.text.isNotEmpty &&
                            value != newPasswordController.text) {
                          return 'Mật khẩu xác nhận không khớp';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
