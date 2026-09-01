// [CẬP NHẬT FILE: lib/screens/manager/notification_management_screen.dart]

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:myshop/models/notification.dart';
import 'package:myshop/services/pocketbase_service.dart';
import 'package:myshop/widgets/manager/add_notification_dialog.dart';

class NotificationManagementScreen extends StatefulWidget {
  const NotificationManagementScreen({super.key});

  @override
  State<NotificationManagementScreen> createState() =>
      _NotificationManagementScreenState();
}

class _NotificationManagementScreenState
    extends State<NotificationManagementScreen> {
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

  // Tạo mới
  Future<void> _handleCreate(String title, String content) async {
    try {
      await pbService.notifications.createNotification(
        title: title,
        content: content,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gửi thông báo thành công!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      _loadNotifications();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
      rethrow;
    }
  }

  // Cập nhật
  Future<void> _handleUpdate(String id, String title, String content) async {
    try {
      await pbService.notifications.updateNotification(
        id: id,
        title: title,
        content: content,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cập nhật thành công!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      _loadNotifications();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
      rethrow;
    }
  }

  // Xóa
  Future<void> _handleDelete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa thông báo này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await pbService.notifications.deleteNotification(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã xóa thông báo'),
              backgroundColor: Colors.green,
            ),
          );
        }
        _loadNotifications();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi xóa: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _showDialog({NotificationModel? notification}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AddNotificationDialog(
          notification: notification,
          onSave: (title, content) {
            if (notification == null) {
              return _handleCreate(title, content);
            } else {
              return _handleUpdate(notification.id, title, content);
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
        title: const Text('Quản lý Thông báo'),
        backgroundColor: Colors.purple.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotifications,
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
              return const Center(child: Text('Chưa có thông báo nào.'));
            }

            return ListView.separated(
              padding: const EdgeInsets.all(8),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final notif = notifications[index];
                return Card(
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
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          notif.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('dd/MM/yyyy HH:mm').format(notif.created),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showDialog(notification: notif),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _handleDelete(notif.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDialog(), // Mở dialog tạo mới
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_alert),
      ),
    );
  }
}
