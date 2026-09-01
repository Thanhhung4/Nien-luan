import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:myshop/screens/auth/login_screen.dart';
import 'package:myshop/screens/employee/employee_profile_screen.dart';
import 'package:myshop/screens/employee/notification_screen.dart';
import 'package:myshop/screens/order/completed_orders_screen.dart';
import 'package:myshop/screens/order/existing_order_screen.dart';
import 'package:myshop/screens/order/order_detail_screen.dart';
import 'package:myshop/services/pocketbase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import 'package:myshop/models/table.dart';
import 'package:myshop/widgets/table_grid_view.dart';

class EmployeeHome extends StatefulWidget {
  const EmployeeHome({super.key});

  @override
  State<EmployeeHome> createState() => _EmployeeHomeState();
}

class _EmployeeHomeState extends State<EmployeeHome> {
  final PocketBaseService pbService = PocketBaseService.instance;
  bool _notificationsSubscribed = false;

  late Future<List<TableModel>> _tablesFuture;

  @override
  void initState() {
    super.initState();
    _tablesFuture = pbService.getTables();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotificationsFromDatabase();

      // Realtime notifications (Messenger-like while app is open)
      _startNotificationsRealtime();
    });
  }

  void _loadTables() {
    setState(() {
      _tablesFuture = pbService.getTables();
    });
  }

  Future<void> _refreshTables() async {
    _loadTables();
    try {
      await _tablesFuture;
    } catch (_) {
      // Ignore; UI will show error state
    }
  }

  // Load notifications từ database vào NotificationProvider
  Future<void> _loadNotificationsFromDatabase() async {
    try {
      final notificationProvider = context.read<NotificationProvider>();
      final notifications = await pbService.notifications.getNotifications();
      if (!mounted) return;

      // Clear existing notifications and add only unread ones from database
      notificationProvider.clearAll();

      for (final notif in notifications) {
        // Only add unread notifications to show badge
        if (!notif.isRead) {
          notificationProvider.addNotification(
            title: notif.title,
            message: notif.content,
            type: NotificationType.system, // Default type
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    }
  }

  Future<void> _startNotificationsRealtime() async {
    if (_notificationsSubscribed) return;

    try {
      await pbService.pb.collection('notifications').subscribe('*', (e) {
        if (!mounted) return;
        if (e.action != 'create') return;

        try {
          final title = e.record?.getStringValue('title') ?? 'Thông báo mới';
          final content = e.record?.getStringValue('content') ?? '';
          final isRead = e.record?.getBoolValue('isRead') ?? false;
          if (isRead) return;

          final notificationProvider = context.read<NotificationProvider>();
          notificationProvider.addNotification(
            title: title,
            message: content,
            type: NotificationType.system,
          );

          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Thông báo mới: $title'),
              action: SnackBarAction(
                label: 'Xem',
                onPressed: _openNotifications,
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        } catch (err) {
          debugPrint('Error handling realtime notification: $err');
        }
      });

      _notificationsSubscribed = true;
      debugPrint('Notifications realtime subscribed');
    } catch (e) {
      debugPrint('Failed to subscribe notifications realtime: $e');
    }
  }

  Future<void> _stopNotificationsRealtime() async {
    if (!_notificationsSubscribed) return;
    try {
      await pbService.pb.collection('notifications').unsubscribe('*');
    } catch (e) {
      debugPrint('Failed to unsubscribe notifications realtime: $e');
    } finally {
      _notificationsSubscribed = false;
    }
  }

  @override
  void dispose() {
    _stopNotificationsRealtime();
    super.dispose();
  }

  void _logout(BuildContext context) {
    context.read<AuthProvider>().logout();
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

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const EmployeeProfileScreen()),
    );
  }

  void _openNotifications() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(builder: (context) => const NotificationScreen()),
        )
        .then((_) {
          // Mark all as read when returning from notification screen
          if (!mounted) return;
          context.read<NotificationProvider>().markAllAsRead();
        });
  }

  Future<void> _onTableTapped(TableModel table) async {
    final Widget target = table.isOccupied
        ? ExistingOrderScreen(table: table)
        : OrderDetailScreen(table: table);

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => target));

    if (!mounted) return;
    await _refreshTables();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn bàn'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.account_circle, color: Colors.white, size: 30),
          tooltip: 'Tài khoản',
          onPressed: _openProfile,
        ),
        actions: [
          // Bell icon with notification badge
          Consumer<NotificationProvider>(
            builder: (context, notificationProvider, child) {
              final unreadCount = notificationProvider.unreadCount;
              debugPrint('Badge rebuilt: unreadCount = $unreadCount');
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications, color: Colors.white),
                    tooltip: 'Thông báo',
                    onPressed: _openNotifications,
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long, color: Colors.white),
            tooltip: 'Hóa đơn đã hoàn thành',
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
                      'Lỗi tải danh sách bàn: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _refreshTables,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          }

          final tables = snapshot.data ?? [];
          if (tables.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.event_seat, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('Chưa có bàn nào trong hệ thống.'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _refreshTables,
                      child: const Text('Tải lại'),
                    ),
                  ],
                ),
              ),
            );
          }

          return TableGridView(
            tables: tables,
            onRefresh: _refreshTables,
            onTableTapped: _onTableTapped,
          );
        },
      ),
    );
  }
}
