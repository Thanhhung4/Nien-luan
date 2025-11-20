import 'package:flutter/material.dart';
import 'package:myshop/models/staff_profile.dart';
import 'employee_list_item.dart'; // Sửa tên file này nếu bạn đổi ở trên

class EmployeeListView extends StatelessWidget {
  final List<StaffProfile> profiles; // <-- ĐỔI TỪ User SANG StaffProfile
  final Future<bool> Function(StaffProfile) onDeleteConfirmed;
  final void Function(StaffProfile) onView;

  const EmployeeListView({
    super.key,
    required this.profiles,
    required this.onDeleteConfirmed,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    if (profiles.isEmpty) {
      return Stack(
        children: [
          ListView(),
          const Center(
            child: Text('Không có nhân viên nào. Hãy thêm người mới!'),
          ),
        ],
      );
    }

    return ListView.separated(
      itemCount: profiles.length,
      itemBuilder: (context, index) {
        final profile = profiles[index];
        return EmployeeListItem(
          // Sửa tên Widget nếu bạn đổi file 1
          profile: profile, // <-- Đã đổi
          onDeleteConfirmed: onDeleteConfirmed,
          onTap: () => onView(profile),
        );
      },
      separatorBuilder: (context, index) => const Divider(height: 1),
    );
  }
}
