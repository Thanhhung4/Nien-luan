import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/pocketbase_service.dart';
import '../../providers/auth_provider.dart';
import '../employee/employee_home.dart';
import '../manager/manager_home.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final pbService = PocketBaseService.instance;
  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
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

  Future<void> _handleLogin() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      _showSnackbar('Vui lòng nhập đầy đủ Email và Mật khẩu.', isError: true);
      return;
    }

    // 1. Bắt đầu loading
    setState(() => isLoading = true);

    try {
      // 2. Thử đăng nhập thông qua AuthProvider
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.login(
        emailController.text,
        passwordController.text,
      );

      if (success && authProvider.userRole != null) {
        final userRole = authProvider.userRole!;

        // 3. Điều hướng theo role
        switch (userRole) {
          case 'employee':
            _navigateTo(const EmployeeHome());
            break;
          case 'manager':
            _navigateTo(const ManagerHome());
            break;
          default:
            _showSnackbar('Vai trò người dùng không hợp lệ.', isError: true);
        }
      } else {
        _showSnackbar(
          'Đăng nhập thất bại. Vui lòng kiểm tra lại thông tin.',
          isError: true,
        );
      }
    } catch (e) {
      _showSnackbar('Lỗi đăng nhập: $e', isError: true);
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
        title: const Text("Login"),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Email Input
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 16),

            // Password Input
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 32),

            // Login Button / Loading Indicator
            SizedBox(
              width: double.infinity,
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _handleLogin,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        "Đăng nhập",
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
