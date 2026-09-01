import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:myshop/models/staff_role.dart';
import 'package:myshop/providers/auth_provider.dart';
import 'package:myshop/screens/employee/employee_home.dart';
import 'package:myshop/screens/manager/manager_home.dart';
import 'package:myshop/services/pocketbase_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final passwordConfirmController = TextEditingController();

  static const _backgroundAssetPath = 'assets/images/login_bg.png';

  final PocketBaseService pbService = PocketBaseService.instance;
  bool isLoading = false;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    passwordConfirmController.dispose();
    super.dispose();
  }

  void _navigateTo(Widget screen) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _handleRegister() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final passwordConfirm = passwordConfirmController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showSnackbar(
        'Vui lòng nhập đầy đủ Họ tên, Email và Mật khẩu.',
        isError: true,
      );
      return;
    }

    if (password != passwordConfirm) {
      _showSnackbar('Mật khẩu xác nhận không khớp.', isError: true);
      return;
    }

    setState(() => isLoading = true);

    try {
      // Tạo tài khoản + hồ sơ nhân viên (liên kết với user_account)
      await pbService.users.addStaffProfile(
        name: name,
        role: StaffRole.employee,
        email: email,
        password: password,
      );

      // Đăng nhập ngay sau khi đăng ký
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.login(email, password);

      if (!success || authProvider.userRole == null) {
        _showSnackbar(
          'Đăng ký thành công nhưng đăng nhập thất bại.',
          isError: true,
        );
        return;
      }

      switch (authProvider.userRole) {
        case 'employee':
          _navigateTo(const EmployeeHome());
          break;
        case 'manager':
          _navigateTo(const ManagerHome());
          break;
        default:
          _showSnackbar('Vai trò người dùng không hợp lệ.', isError: true);
      }
    } catch (e) {
      _showSnackbar('Lỗi đăng ký: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đăng ký'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(_backgroundAssetPath, fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: Align(
              alignment: const Alignment(0, -0.1),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Material(
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: 'Họ tên',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.email),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Mật khẩu',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.lock),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: passwordConfirmController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Xác nhận mật khẩu',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            child: isLoading
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : ElevatedButton(
                                    onPressed: _handleRegister,
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 15,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      'Tạo tài khoản',
                                      style: TextStyle(fontSize: 18),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
