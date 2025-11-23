// [CẬP NHẬT FILE: lib/screens/manager/employee_detail_screen.dart]

import 'package:flutter/material.dart';
import 'package:myshop/models/staff_profile.dart';
import 'package:myshop/widgets/manager/edit_employee_dialog.dart';
import 'package:myshop/services/pocketbase_service.dart';
import 'package:myshop/models/staff_role.dart';
import 'package:myshop/screens/manager/single_employee_salary_screen.dart';
import 'package:myshop/screens/manager/staff_schedule_detail_screen.dart';

class EmployeeDetailScreen extends StatefulWidget {
  final StaffProfile profile;
  final VoidCallback onProfileUpdated;
  final UpdateStaffDetailsCallback onUpdateDetails;

  const EmployeeDetailScreen({
    super.key,
    required this.profile,
    required this.onProfileUpdated,
    required this.onUpdateDetails,
  });

  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen> {
  late StaffProfile _currentProfile;

  @override
  void initState() {
    super.initState();
    _currentProfile = widget.profile;
  }

  Future<void> _reloadProfileData() async {
    try {
      final updatedProfile = await PocketBaseService.instance.users
          .getStaffProfile(_currentProfile.id);
      setState(() {
        _currentProfile = updatedProfile;
      });
      widget.onProfileUpdated();
    } catch (e) {
      print("Lỗi tải lại hồ sơ: $e");
    }
  }

  void _showEditEmployeeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return EditEmployeeDialog(
          profile: _currentProfile,
          // SỬA LỖI Ở ĐÂY: Callback này giờ không nhận salary nữa
          onUpdate:
              ({
                required String profileId,
                required String name,
                required StaffRole role,
                required String status,
                String? userId,
                String? newEmail,
                String? newPassword,
              }) async {
                try {
                  // Gọi hàm từ màn hình cha (cũng không truyền salary)
                  await widget.onUpdateDetails(
                    profileId: profileId,
                    name: name,
                    role: role,
                    status: status,
                    userId: userId,
                    newEmail: newEmail,
                    newPassword: newPassword,
                  );

                  await _reloadProfileData();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Lỗi tải lại chi tiết: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentProfile.name),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [_buildHeader(), _buildInfoCard(), _buildScheduleButton()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showEditEmployeeDialog,
        icon: const Icon(Icons.edit),
        label: const Text('Chỉnh sửa'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.indigo.shade50,
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.indigo.shade200,
            child: Text(
              _currentProfile.name.isNotEmpty ? _currentProfile.name[0] : '?',
              style: const TextStyle(fontSize: 48, color: Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _currentProfile.name,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Text(
            _currentProfile.role.display,
            style: TextStyle(fontSize: 18, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thông tin chi tiết',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _InfoRow(
              icon: Icons.badge,
              label: 'Trạng thái',
              value: _currentProfile.status,
            ),
            _InfoRow(
              icon: Icons.email,
              label: 'Email đăng nhập',
              value: _currentProfile.email,
            ),

            InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        SingleEmployeeSalaryScreen(profile: _currentProfile),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.attach_money,
                      color: Colors.indigo.shade300,
                      size: 20,
                    ),
                    const SizedBox(width: 16),
                    const Text("Lương", style: TextStyle(color: Colors.grey)),
                    const Spacer(),
                    Text(
                      "Xem chi tiết",
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleButton() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  StaffScheduleDetailScreen(profile: _currentProfile),
            ),
          );
          await _reloadProfileData();
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.calendar_month, color: Colors.teal.shade400, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Lịch làm việc & Vi phạm',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Text(
                      'Xem lịch cố định, thêm ngày nghỉ/đi trễ...',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.indigo.shade300, size: 20),
          const SizedBox(width: 16),
          Text(label, style: const TextStyle(color: Colors.grey)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'N/A',
              style: const TextStyle(fontWeight: FontWeight.w500),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
