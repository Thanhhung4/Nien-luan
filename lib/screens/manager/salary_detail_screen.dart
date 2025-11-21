// [CẬP NHẬT FILE: lib/screens/manager/salary_detail_screen.dart]

import 'package:flutter/material.dart';
import 'package:myshop/models/staff_profile.dart';
import 'package:myshop/utils/currency_formatter.dart';

class SalaryDetailScreen extends StatelessWidget {
  final List<StaffProfile> profiles;
  final double totalPayroll;
  final Map<String, double> salaryMap; // <-- THÊM BIẾN NÀY

  const SalaryDetailScreen({
    super.key,
    required this.profiles,
    required this.totalPayroll,
    required this.salaryMap, // <-- THÊM VÀO CONSTRUCTOR
  });

  @override
  Widget build(BuildContext context) {
    // Lọc ra danh sách nhân viên đang hoạt động ('active') để hiển thị
    final activeProfiles = profiles.where((p) => p.status == 'active').toList();

    // Sắp xếp lương thực nhận từ cao đến thấp
    activeProfiles.sort((a, b) {
      final salaryA = salaryMap[a.id] ?? a.salary;
      final salaryB = salaryMap[b.id] ?? b.salary;
      return salaryB.compareTo(salaryA);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết Lương (Thực nhận)'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: activeProfiles.length,
        itemBuilder: (context, index) {
          final profile = activeProfiles[index];

          // Lấy lương thực tế từ Map, nếu không có thì lấy lương cứng
          final realSalary = salaryMap[profile.id] ?? profile.salary;
          // Tính số tiền bị trừ
          final deduction = profile.salary - realSalary;

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
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            // Logic hiển thị phụ đề: Nếu bị trừ tiền thì hiện dòng đỏ
            subtitle: deduction > 0
                ? Text(
                    "Lương cứng: ${formatCurrency(profile.salary)}\n- Phạt: ${formatCurrency(deduction)}",
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.red,
                      height: 1.3,
                    ),
                  )
                : Text(
                    profile.role.display,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  "Thực lĩnh",
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
                Text(
                  formatCurrency(realSalary),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.indigo,
                  ),
                ),
              ],
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
                  'Tổng thực chi (tháng):',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Flexible(
                child: Text(
                  formatCurrency(totalPayroll),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.indigo,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
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
