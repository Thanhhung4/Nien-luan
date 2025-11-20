import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:myshop/models/notification.dart'; // Model bạn đã tạo
import 'package:myshop/services/pocketbase_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final pbService = PocketBaseService.instance;
  late Future<List<NotificationModel>> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (mounted) {
      setState(() {
        _notificationsFuture = pbService.notifications.getNotifications();
      });
    }
  }

  // Hàm hiển thị chi tiết thông báo (trong Dialog)
  void _showNotificationDetail(NotificationModel notif) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notif.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gửi lúc: ${DateFormat('HH:mm dd/MM/yyyy').format(notif.created)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Divider(height: 20),
              Text(notif.content),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        backgroundColor: Colors.purple.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotifications,
            tooltip: 'Tải lại',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        child: FutureBuilder<List<NotificationModel>>(
          future: _notificationsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Lỗi: ${snapshot.error}'));
            }
            final notifications = snapshot.data ?? [];
            if (notifications.isEmpty) {
              return Stack(
                children: [
                  ListView(), // Để RefreshIndicator hoạt động
                  const Center(child: Text('Không có thông báo mới nào.')),
                ],
              );
            }

            // Hiển thị danh sách thông báo
            return ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notif = notifications[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  elevation: 2,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.purple.shade100,
                      child: const Icon(Icons.campaign, color: Colors.purple),
                    ),
                    title: Text(
                      notif.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      DateFormat('HH:mm - dd/MM/yyyy').format(notif.created),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        _showNotificationDetail(notif), // Bấm để xem chi tiết
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
