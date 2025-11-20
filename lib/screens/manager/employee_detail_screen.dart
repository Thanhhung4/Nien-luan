// [DÁN TOÀN BỘ CODE NÀY VÀO lib/screens/manager/employee_detail_screen.dart]

import 'package:flutter/material.dart';
import 'package:myshop/models/staff_profile.dart';
import 'package:myshop/widgets/manager/edit_employee_dialog.dart';
import 'package:myshop/services/pocketbase_service.dart'; // Cần cho hàm callback
import 'package:myshop/models/staff_role.dart'; // Cần cho hàm callback
import 'package:myshop/utils/currency_formatter.dart'; // <-- Import mới để format lương

class EmployeeDetailScreen extends StatefulWidget {
  final StaffProfile profile;
  // Callback để khi sửa xong, màn hình trước (management) có thể tải lại
  final VoidCallback onProfileUpdated;
  // Callback cho hàm Sửa
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

  // Hàm hiển thị Dialog Sửa
  void _showEditEmployeeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return EditEmployeeDialog(
          profile: _currentProfile,
          onUpdate:
              ({
                required String profileId,
                required String name,
                required StaffRole role,
                required double salary,
                required String status,
                String? userId,
                String? newEmail,
                String? newPassword,
              }) async {
                try {
                  // 1. Gọi hàm update service
                  await widget.onUpdateDetails(
                    profileId: profileId,
                    name: name,
                    role: role,
                    salary: salary,
                    status: status,
                    userId: userId,
                    newEmail: newEmail,
                    newPassword: newPassword,
                  );

                  // 2. Tải lại thông tin mới từ DB
                  final pbService = PocketBaseService.instance;
                  // Dùng hàm getStaffProfile mới, luôn hoạt động
                  final updatedProfile = await pbService.users.getStaffProfile(
                    _currentProfile.id,
                  );

                  // 3. Cập nhật UI của màn hình này
                  setState(() {
                    _currentProfile = updatedProfile;
                  });

                  // 4. Báo cho màn hình management tải lại
                  widget.onProfileUpdated();
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
        children: [_buildHeader(), _buildInfoCard(), _buildScheduleCard()],
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
            _InfoRow(
              icon: Icons.attach_money,
              label: 'Lương',
              // SỬA Ở ĐÂY: Dùng formatCurrency thay vì toStringAsFixed
              value: formatCurrency(_currentProfile.salary),
            ),
            // ĐÃ XÓA DÒNG PROFILE ID Ở ĐÂY
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleCard() {
    // Lọc ra những ngày có ca làm
    final List<Widget> scheduleRows = [];

    // Sắp xếp các ngày T2 -> CN
    const List<String> allDays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

    for (var day in allDays) {
      final shifts = _currentProfile.defaultSchedule[day] ?? [];
      if (shifts.isNotEmpty) {
        scheduleRows.add(
          _InfoRow(
            icon: Icons.calendar_today,
            label: day, // Ví dụ: T2
            value: shifts.join(', '), // Ví dụ: Ca sáng, Ca chiều
          ),
        );
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lịch cố định',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),

            // Nếu không có lịch cố định nào
            if (scheduleRows.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Chưa có lịch cố định.',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            // Nếu có, hiển thị các ngày làm
            else
              ...scheduleRows,
          ],
        ),
      ),
    );
  }
}

// Widget helper
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
        crossAxisAlignment: CrossAxisAlignment.start, // Cho phép xuống dòng
        children: [
          Icon(icon, color: Colors.indigo.shade300, size: 20),
          const SizedBox(width: 16),
          Text(label, style: const TextStyle(color: Colors.grey)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'N/A',
              style: const TextStyle(fontWeight: FontWeight.w500),
              textAlign: TextAlign.right, // Căn phải cho đẹp
            ),
          ),
        ],
      ),
    );
  }
}
