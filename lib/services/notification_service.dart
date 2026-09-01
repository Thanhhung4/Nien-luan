// [CẬP NHẬT FILE: lib/services/notification_service.dart]

import 'package:pocketbase/pocketbase.dart';
import 'package:myshop/models/notification.dart';

class NotificationService {
  final PocketBase pb;

  NotificationService(this.pb);

  String _formatPbError(Object error) {
    if (error is ClientException) {
      final status = error.statusCode;
      final message = (error.response['message'] ?? '').toString();
      final data = error.response['data'];

      if (message.isNotEmpty && data != null) {
        return 'PocketBase $status: $message | data: $data';
      }
      if (message.isNotEmpty) {
        return 'PocketBase $status: $message';
      }
      return 'PocketBase $status: $error';
    }
    return error.toString();
  }

  // Lấy danh sách
  Future<List<NotificationModel>> getNotifications() async {
    try {
      final records = await pb
          .collection('notifications')
          .getFullList(sort: '-created');
      return records.map((r) => NotificationModel.fromRecord(r)).toList();
    } catch (e) {
      print('Error fetching notifications: $e');
      throw Exception('Failed to load notifications: ${_formatPbError(e)}');
    }
  }

  // Tạo mới
  Future<void> createNotification({
    required String title,
    required String content, // Dùng content
  }) async {
    try {
      await pb
          .collection('notifications')
          .create(
            body: {
              'title': title,
              'content': content, // Dùng content
              // PocketBase schema thường có cờ đọc/chưa đọc; gửi mặc định để tránh lỗi field bắt buộc.
              'isRead': false,
            },
          );
    } catch (e) {
      throw Exception('Failed to create notification: ${_formatPbError(e)}');
    }
  }

  // --- HÀM MỚI: CẬP NHẬT ---
  Future<void> updateNotification({
    required String id,
    required String title,
    required String content, // Dùng content
  }) async {
    try {
      await pb
          .collection('notifications')
          .update(
            id,
            body: {
              'title': title,
              'content': content, // Dùng content
            },
          );
    } catch (e) {
      throw Exception('Failed to update notification: ${_formatPbError(e)}');
    }
  }

  // --- HÀM MỚI: XÓA ---
  Future<void> deleteNotification(String id) async {
    try {
      await pb.collection('notifications').delete(id);
    } catch (e) {
      throw Exception('Failed to delete notification: ${_formatPbError(e)}');
    }
  }

  // --- HÀM MỚI: MARK AS READ ---
  Future<void> markAsRead(String id) async {
    try {
      await pb.collection('notifications').update(id, body: {'isRead': true});
    } catch (e) {
      throw Exception('Failed to mark notification as read: ${_formatPbError(e)}');
    }
  }
}
