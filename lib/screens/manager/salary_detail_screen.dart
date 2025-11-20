// [FILE: lib/screens/manager/salary_detail_screen.dart]

import 'package:flutter/material.dart';
import 'package:myshop/models/staff_profile.dart';
import 'package:myshop/utils/currency_formatter.dart';

class SalaryDetailScreen extends StatelessWidget {
  final List<StaffProfile> profiles;
  final double totalPayroll;

  const SalaryDetailScreen({
    super.key,
    required this.profiles,
    required this.totalPayroll,
  });

  @override
  Widget build(BuildContext context) {
    // Lọc ra danh sách nhân viên đang hoạt động ('active') để hiển thị
    final activeProfiles = profiles.where((p) => p.status == 'active').toList();

    // Sắp xếp lương từ cao đến thấp
    activeProfiles.sort((a, b) => b.salary.compareTo(a.salary));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết Lương Nhân viên'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: activeProfiles.length,
        itemBuilder: (context, index) {
          final profile = activeProfiles[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: CircleAvatar(
              backgroundColor: Colors.indigo.shade100,
              child: Text(
                profile.name.isNotEmpty ? profile.name[0] : '?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo.shade700,
                ),
              ),
            ),
            title: Text(
              profile.name,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              profile.role.display,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            trailing: Text(
              formatCurrency(profile.salary),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14, // Giảm font để hiển thị số dài
                color: Colors.indigo,
              ),
            ),
          );
        },
        separatorBuilder: (context, index) => const Divider(height: 1),
      ),
      // Thanh tổng kết ở dưới cùng
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        elevation: 10,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Tổng chi phí lương (tháng):',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Flexible(
                child: Text(
                  formatCurrency(totalPayroll),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.indigo,
                    fontWeight: FontWeight.bold,
                    fontSize: 16, // Giảm font để hiển thị số lớn
                  ),
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
