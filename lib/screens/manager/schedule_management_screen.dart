// [DÁN TOÀN BỘ CODE NÀY VÀO lib/screens/manager/schedule_management_screen.dart]

import 'package:flutter/material.dart';
import 'package:myshop/models/staff_profile.dart';
import 'package:myshop/services/pocketbase_service.dart';
import 'staff_schedule_detail_screen.dart';

class ScheduleManagementScreen extends StatefulWidget {
  const ScheduleManagementScreen({super.key});

  @override
  State<ScheduleManagementScreen> createState() =>
      _ScheduleManagementScreenState();
}

class _ScheduleManagementScreenState extends State<ScheduleManagementScreen> {
  final pbService = PocketBaseService.instance;
  late Future<List<StaffProfile>> _profilesFuture;

  @override
  void initState() {
    super.initState();
    _loadStaffProfiles();
  }

  Future<void> _loadStaffProfiles() async {
    if (mounted) {
      setState(() {
        _profilesFuture = pbService.users.getStaffProfiles();
      });
    }
  }

  // --- SỬA HÀM NÀY (ĐỂ TẢI LẠI DỮ LIỆU) ---
  void _navigateToExceptions(StaffProfile profile) async {
    // Chờ màn hình StaffScheduleDetailScreen đóng lại
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StaffScheduleDetailScreen(profile: profile),
      ),
    );

    // Sau khi màn hình đó đóng, tải lại danh sách
    // để cập nhật profile mới nhất (nếu có thay đổi)
    _loadStaffProfiles();
  }
  // --- KẾT THÚC SỬA ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Lịch làm việc'),
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStaffProfiles,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStaffProfiles,
        child: FutureBuilder<List<StaffProfile>>(
          future: _profilesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Lỗi: ${snapshot.error}'));
            }
            final profiles = snapshot.data ?? [];
            if (profiles.isEmpty) {
              return const Center(child: Text('Không có nhân viên nào.'));
            }

            return ListView.builder(
              itemCount: profiles.length,
              itemBuilder: (context, index) {
                final profile = profiles[index];
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      profile.name.isNotEmpty ? profile.name[0] : '?',
                    ),
                  ),
                  title: Text(
                    profile.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(profile.role.display),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _navigateToExceptions(profile),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
