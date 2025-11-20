import 'package:flutter/material.dart';
import 'package:myshop/services/pocketbase_service.dart';
// Import models và widgets mới
import 'package:myshop/models/staff_profile.dart';
import 'package:myshop/models/staff_role.dart';
import 'package:myshop/widgets/manager/employee_list_view.dart';
import 'package:myshop/widgets/manager/add_employee_dialog.dart';
import 'package:myshop/widgets/manager/edit_employee_dialog.dart';
import 'package:myshop/screens/manager/employee_detail_screen.dart';

class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({super.key});

  @override
  State<EmployeeManagementScreen> createState() =>
      _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> {
  final PocketBaseService pbService = PocketBaseService.instance;
  late Future<List<StaffProfile>> _staffProfilesFuture; // <-- ĐÃ SỬA

  @override
  void initState() {
    super.initState();
    _loadStaffProfiles();
  }

  Future<void> _loadStaffProfiles() async {
    // <-- ĐÃ SỬA
    if (mounted) {
      setState(() {
        _staffProfilesFuture = pbService.users.getStaffProfiles(); // <-- ĐÃ SỬA
      });
    }
  }

  // Hàm hiển thị Snackbar
  void _showSnackbar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
    }
  }

  // --- LOGIC XỬ LÝ MỚI ---

  void _showAddEmployeeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AddEmployeeDialog(onAdd: _handleAddStaffProfile); // <-- ĐÃ SỬA
      },
    );
  }

  // Xử lý thêm hồ sơ (Đã đơn giản hóa)
  Future<void> _handleAddStaffProfile({
    required String name,
    required StaffRole role,
    double salary = 0.0,
    String? email,
    String? password,
  }) async {
    try {
      await pbService.users.addStaffProfile(
        name: name,
        role: role,
        salary: salary,
        email: email,
        password: password,
      );
      _showSnackbar('Thêm nhân viên $name thành công!', Colors.green);
      _loadStaffProfiles();
    } catch (e) {
      _showSnackbar('Lỗi thêm nhân viên: $e', Colors.red);
      throw e; // Ném lỗi để dialog biết
    }
  }

  // Xử lý xóa hồ sơ
  Future<bool> _handleDeleteStaffProfile(StaffProfile profile) async {
    // <-- ĐÃ SỬA
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Xác nhận Xóa'),
            content: Text(
              'Bạn có chắc chắn muốn xóa ${profile.name} không? Thao tác này KHÔNG THỂ hoàn tác.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Xóa', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed) {
      try {
        await pbService.users.deleteStaffProfile(profile); // <-- ĐÃ SỬA
        _showSnackbar(
          'Xóa nhân viên ${profile.name} thành công!',
          Colors.green,
        );
        _loadStaffProfiles();
        return true;
      } catch (e) {
        _showSnackbar('Lỗi xóa nhân viên: $e', Colors.red);
        return false;
      }
    }
    return false;
  }

  void _navigateToDetail(StaffProfile profile) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EmployeeDetailScreen(
          profile: profile,
          // Truyền hàm onUpdate vào
          onUpdateDetails: _handleUpdateStaffDetails,
          // Truyền hàm yêu cầu tải lại list
          onProfileUpdated: () {
            _loadStaffProfiles();
          },
        ),
      ),
    );
  }

  // Xử lý cập nhật hồ sơ (ĐÃ NÂNG CẤP)
  Future<void> _handleUpdateStaffDetails({
    required String profileId,
    required String name,
    required StaffRole role,
    required double salary,
    required String status,
    // Thêm các tham số mới
    String? userId,
    String? newEmail,
    String? newPassword,
  }) async {
    try {
      await pbService.users.updateStaffDetails(
        profileId: profileId,
        name: name,
        role: role,
        salary: salary,
        status: status,
        // Gửi dữ liệu tài khoản
        userId: userId,
        newEmail: newEmail,
        newPassword: newPassword,
      );
      _showSnackbar('Cập nhật thông tin thành công!', Colors.green);
      _loadStaffProfiles(); // Làm mới danh sách
    } catch (e) {
      _showSnackbar('Lỗi cập nhật: $e', Colors.red);
      throw e; // Ném lại lỗi
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Quản lý Nhân viên"),
        backgroundColor: Colors.indigo.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStaffProfiles, // <-- ĐÃ SỬA
            tooltip: 'Làm mới danh sách',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStaffProfiles, // <-- ĐÃ SỬA
        child: FutureBuilder<List<StaffProfile>>(
          // <-- ĐÃ SỬA
          future: _staffProfilesFuture, // <-- ĐÃ SỬA
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 40,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Lỗi tải danh sách nhân viên: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _loadStaffProfiles,
                        child: const Text('Thử tải lại'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final profiles = snapshot.data ?? []; // <-- ĐÃ SỬA
            return EmployeeListView(
              profiles: profiles, // <-- ĐÃ SỬA
              onDeleteConfirmed: _handleDeleteStaffProfile, // <-- ĐÃ SỬA
              onView: _navigateToDetail,
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddEmployeeDialog,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Thêm NV'),
      ),
    );
  }
}
