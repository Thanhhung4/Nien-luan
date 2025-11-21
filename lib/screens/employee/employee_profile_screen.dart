import 'package:flutter/material.dart';
import 'package:myshop/models/staff_profile.dart'; // <-- IMPORT MỚI
import 'package:myshop/services/pocketbase_service.dart';
import 'package:myshop/screens/employee/edit_profile_screen.dart';
import 'package:myshop/screens/employee/notification_screen.dart';
import 'package:myshop/screens/employee/schedule_screen.dart'; // <-- THÊM IMPORT NÀY

class EmployeeProfileScreen extends StatefulWidget {
  const EmployeeProfileScreen({super.key});

  @override
  State<EmployeeProfileScreen> createState() => _EmployeeProfileScreenState();
}

class _EmployeeProfileScreenState extends State<EmployeeProfileScreen> {
  final pbService = PocketBaseService.instance;
  StaffProfile? currentProfile; // <-- ĐỔI TỪ User SANG StaffProfile
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  Future<void> _loadCurrentProfile() async {
    setState(() {
      _error = null;
      currentProfile = null;
    });
    try {
      // Lấy ID của user đang đăng nhập
      final userId = pbService.pb.authStore.record?.id;
      if (userId == null) {
        throw Exception("Không tìm thấy ID người dùng đã đăng nhập.");
      }
      // Gọi service mới để lấy hồ sơ (profile)
      final profile = await pbService.users.getStaffProfileForUser(userId);
      if (mounted) {
        setState(() {
          currentProfile = profile;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  // Hàm helper để điều hướng
  void _navigateTo(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => screen));
  }

  // Hàm điều hướng đến màn hình chỉnh sửa
  void _navigateToEditProfile() {
    if (currentProfile == null) return;

    Navigator.of(context)
        .push<bool>(
          MaterialPageRoute(
            // Truyền StaffProfile
            builder: (context) => EditProfileScreen(profile: currentProfile!),
          ),
        )
        .then((didUpdate) {
          if (didUpdate == true) {
            _loadCurrentProfile(); // Tải lại thông tin
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tài khoản của tôi'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(), // Tách body ra
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text('Lỗi: $_error'));
    }

    if (currentProfile == null) {
      // Trường hợp này không nên xảy ra nếu không lỗi
      return const Center(child: Text('Không tải được hồ sơ.'));
    }

    // Hiển thị khi đã có profile
    return ListView(
      children: [
        UserAccountsDrawerHeader(
          accountName: Text(
            currentProfile!.name.isNotEmpty
                ? currentProfile!.name
                : 'Chưa cập nhật tên',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          accountEmail: Text(currentProfile!.email),
          currentAccountPicture: CircleAvatar(
            backgroundColor: Colors.white,
            child: Text(
              (currentProfile!.name.isNotEmpty
                      ? currentProfile!.name[0]
                      : currentProfile!.email[0])
                  .toUpperCase(),
              style: TextStyle(
                fontSize: 40.0,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
          decoration: BoxDecoration(color: Theme.of(context).primaryColor),
        ),

        // --- PHẦN CHỨC NĂNG ---
        ListTile(
          leading: const Icon(Icons.edit_note),
          title: const Text('Chỉnh sửa thông tin'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _navigateToEditProfile,
        ),
        ListTile(
          leading: const Icon(Icons.calendar_month),
          title: const Text('Xem lịch làm việc'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            if (currentProfile != null) {
              _navigateTo(
                // Điều hướng đến màn hình lịch thật
                ScheduleScreen(profile: currentProfile!), // <-- ĐÃ SỬA
              );
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.notifications),
          title: const Text('Thông báo'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            _navigateTo(const NotificationScreen());
          },
        ),
      ],
    );
  }

  bool get _isLoading => currentProfile == null && _error == null;
}
