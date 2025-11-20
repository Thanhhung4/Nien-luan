// lib/screens/employee/employee_home.dart

import 'package:flutter/material.dart';
import 'package:myshop/services/pocketbase_service.dart';
import 'package:myshop/screens/auth/login_screen.dart';
import 'package:myshop/models/table.dart';
// Import các màn hình Order
import 'package:myshop/screens/order/order_detail_screen.dart';
import 'package:myshop/screens/order/existing_order_screen.dart';
import 'package:myshop/screens/order/completed_orders_screen.dart';
// Import widget
import 'package:myshop/widgets/table_grid_view.dart';
import 'package:myshop/screens/employee/employee_profile_screen.dart';
// PocketBase
import 'package:pocketbase/pocketbase.dart';

class EmployeeHome extends StatefulWidget {
  const EmployeeHome({super.key});

  @override
  State<EmployeeHome> createState() => _EmployeeHomeState();
}

class _EmployeeHomeState extends State<EmployeeHome> {
  final PocketBaseService pbService = PocketBaseService.instance;

  late Future<List<TableModel>> _tablesFuture;

  // Lưu unsubscribe riêng cho màn hình này
  UnsubscribeFunc? _unsubscribe;

  @override
  void initState() {
    super.initState();
    _tablesFuture = pbService.getTables();
    _subscribeToTableChanges();
  }

  @override
  void dispose() {
    _unsubscribeFromTableChanges();
    super.dispose();
  }

  void _subscribeToTableChanges() async {
    print('Đang đăng ký lắng nghe collection "tables"...');

    _unsubscribe = await pbService.pb.collection('tables').subscribe('*', (e) {
      // e là dynamic
      print('Realtime event: action=${e.action}, id=${e.record?.id}');
      if (mounted) {
        _loadTables();
      }
    });
  }

  void _unsubscribeFromTableChanges() {
    if (_unsubscribe != null) {
      print('Đang hủy lắng nghe collection "tables"...');
      _unsubscribe!();
      _unsubscribe = null;
    }
  }

  Future<void> _loadTables() async {
    if (!mounted) return;
    setState(() {
      _tablesFuture = pbService.getTables();
    });
    try {
      await _tablesFuture;
    } catch (e) {
      print('Lỗi khi tải bàn: $e');
    }
  }

  void _logout(BuildContext context) {
    pbService.logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  void _navigateToCompletedOrders() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const CompletedOrdersScreen()),
    );
  }

  void _onTableTapped(TableModel table) async {
    bool? didUpdate;

    if (table.isOccupied) {
      didUpdate = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => ExistingOrderScreen(table: table),
        ),
      );
    } else {
      didUpdate = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => OrderDetailScreen(table: table),
        ),
      );
    }

    // Không cần load lại vì Realtime đã xử lý
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Quản lý Bàn"),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.account_circle, color: Colors.white, size: 30),
          tooltip: 'Tài khoản',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const EmployeeProfileScreen(),
              ),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long, color: Colors.white),
            tooltip: 'Xem hóa đơn đã hoàn thành',
            onPressed: _navigateToCompletedOrders,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Đăng xuất',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: FutureBuilder<List<TableModel>>(
        future: _tablesFuture,
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
                      'Lỗi tải danh sách bàn. Chi tiết: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _loadTables,
                      child: const Text('Thử tải lại'),
                    ),
                  ],
                ),
              ),
            );
          }

          final tables = snapshot.data!;
          if (tables.isEmpty) {
            return RefreshIndicator(
              onRefresh: _loadTables,
              child: ListView(
                children: [
                  Center(
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).size.height * 0.3,
                      ),
                      child: const Text(
                        'Không tìm thấy bàn nào. Vui lòng thêm bàn trên PocketBase.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return TableGridView(
            tables: tables,
            onRefresh: _loadTables,
            onTableTapped: _onTableTapped,
          );
        },
      ),
    );
  }
}
