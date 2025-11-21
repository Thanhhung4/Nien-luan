// [CẬP NHẬT FILE: lib/services/notification_service.dart]

import 'package:pocketbase/pocketbase.dart';
import 'package:myshop/models/notification.dart';

class NotificationService {
  final PocketBase pb;

  NotificationService(this.pb);

  // Lấy danh sách
  Future<List<NotificationModel>> getNotifications() async {
    try {
      final records = await pb
          .collection('notifications')
          .getFullList(sort: '-created');
      return records.map((r) => NotificationModel.fromRecord(r)).toList();
    } catch (e) {
      print('Error fetching notifications: $e');
      throw Exception('Failed to load notifications: $e');
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
            },
          );
    } catch (e) {
      throw Exception('Failed to create notification: $e');
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
      throw Exception('Failed to update notification: $e');
    }
  }

  // --- HÀM MỚI: XÓA ---
  Future<void> deleteNotification(String id) async {
    try {
      await pb.collection('notifications').delete(id);
    } catch (e) {
      throw Exception('Failed to delete notification: $e');
    }
  }
}
