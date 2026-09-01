// [DÁN TOÀN BỘ CODE NÀY VÀO lib/screens/manager/manager_home.dart]

import 'package:flutter/material.dart';
import 'package:myshop/screens/auth/login_screen.dart';
import 'package:myshop/services/pocketbase_service.dart';
import 'package:myshop/screens/manager/manage_menu.dart';
import 'package:myshop/screens/manager/employee_management_screen.dart';
import 'package:myshop/screens/manager/notification_management_screen.dart';
import 'package:myshop/screens/manager/reports.dart';
import 'package:myshop/screens/order/completed_orders_screen.dart';
import 'package:myshop/screens/manager/inventory_management_screen.dart';
import 'package:myshop/screens/manager/table_management_screen.dart';

class ManagerHome extends StatelessWidget {
  const ManagerHome({super.key});

  void _logout(BuildContext context) {
    PocketBaseService.instance.logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Responsive design: điều chỉnh số cột theo kích thước màn hình
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 900
        ? 4 // Desktop: 4 cột
        : screenWidth > 600
        ? 3 // Tablet: 3 cột
        : 2; // Mobile: 2 cột

    final padding = screenWidth > 600 ? 24.0 : 16.0;
    final spacing = screenWidth > 600 ? 20.0 : 16.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang Quản lý'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: GridView.count(
        crossAxisCount: crossAxisCount,
        padding: EdgeInsets.all(padding),
        childAspectRatio: 1.1,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        children: [
          _buildDashboardButton(
            context,
            icon: Icons.table_restaurant,
            label: 'Quản lý Bàn',
            color: Colors.teal,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const TableManagementScreen(),
                ),
              );
            },
          ),
          _buildDashboardButton(
            context,
            icon: Icons.assignment,
            label: 'Quản lý Thực đơn',
            color: Colors.orange,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ManageMenuScreen(),
                ),
              );
            },
          ),
          _buildDashboardButton(
            context,
            icon: Icons.people,
            label: 'Quản lý Nhân viên',
            color: Colors.indigo,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const EmployeeManagementScreen(),
                ),
              );
            },
          ),

          _buildDashboardButton(
            context,
            icon: Icons.warehouse,
            label: 'Quản lý Kho',
            color: Colors.brown,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const InventoryManagementScreen(),
                ),
              );
            },
          ),

          _buildDashboardButton(
            context,
            icon: Icons.bar_chart,
            label: 'Báo cáo',
            // --- SỬA LỖI: ĐỔI TỪ AMBER SANG ORANGE ---
            color: Colors.orange,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ReportsScreen()),
              );
            },
          ),
          _buildDashboardButton(
            context,
            icon: Icons.receipt_long,
            label: 'Lịch sử Hóa đơn',
            color: Colors.blueGrey,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CompletedOrdersScreen(),
                ),
              );
            },
          ),
          _buildDashboardButton(
            context,
            icon: Icons.notifications,
            label: 'Gửi Thông báo',
            color: Colors.red,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const NotificationManagementScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- SỬA LỖI: ĐỔI 'Color' THÀNH 'MaterialColor' ---
  Widget _buildDashboardButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required MaterialColor color, // <-- Sửa ở đây
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4.0,
      color: color.shade50, // <-- Dùng shade
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50.0, color: color.shade700), // <-- Dùng shade
            const SizedBox(height: 16.0),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
                color: color.shade900, // <-- Dùng shade
              ),
            ),
          ],
        ),
      ),
    );
  }
}
