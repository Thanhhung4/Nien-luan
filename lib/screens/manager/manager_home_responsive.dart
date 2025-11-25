import 'package:flutter/material.dart';
import 'package:myshop/screens/auth/login_screen.dart';
import 'package:myshop/services/pocketbase_service.dart';
import 'package:myshop/screens/manager/manage_menu.dart';
import 'package:myshop/screens/manager/employee_management_screen.dart';
import 'package:myshop/screens/manager/notification_management_screen.dart';
import 'package:myshop/screens/manager/reports.dart';
import 'package:myshop/screens/order/completed_orders_screen.dart';
import 'package:myshop/screens/manager/inventory_management_screen.dart';

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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;

    int crossAxisCount = 2; // Mobile
    if (isTablet) crossAxisCount = 3;
    if (screenWidth >= 1200) crossAxisCount = 4; // Desktop

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
      body: GridView.builder(
        padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 1.1,
          crossAxisSpacing: isMobile ? 12.0 : 16.0,
          mainAxisSpacing: isMobile ? 12.0 : 16.0,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          final buttons = [
            {
              'icon': Icons.assignment,
              'label': 'Quản lý Thực đơn',
              'color': Colors.orange,
              'screen': const ManageMenuScreen(),
            },
            {
              'icon': Icons.people,
              'label': 'Quản lý Nhân viên',
              'color': Colors.indigo,
              'screen': const EmployeeManagementScreen(),
            },
            {
              'icon': Icons.warehouse,
              'label': 'Quản lý Kho',
              'color': Colors.brown,
              'screen': const InventoryManagementScreen(),
            },
            {
              'icon': Icons.bar_chart,
              'label': 'Báo cáo',
              'color': Colors.orange,
              'screen': const ReportsScreen(),
            },
            {
              'icon': Icons.receipt_long,
              'label': 'Lịch sử Hóa đơn',
              'color': Colors.blueGrey,
              'screen': const CompletedOrdersScreen(),
            },
            {
              'icon': Icons.notifications,
              'label': 'Gửi Thông báo',
              'color': Colors.red,
              'screen': const NotificationManagementScreen(),
            },
          ];

          final button = buttons[index];
          return _buildDashboardButton(
            context,
            icon: button['icon'] as IconData,
            label: button['label'] as String,
            color: button['color'] as MaterialColor,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => button['screen'] as Widget,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDashboardButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required MaterialColor color,
    required VoidCallback onTap,
  }) {
    final isSmallScreen = MediaQuery.of(context).size.width < 400;

    return Card(
      elevation: 4.0,
      color: color.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: isSmallScreen ? 40.0 : 50.0,
              color: color.shade700,
            ),
            SizedBox(height: isSmallScreen ? 12.0 : 16.0),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isSmallScreen ? 14.0 : 16.0,
                  fontWeight: FontWeight.bold,
                  color: color.shade900,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
