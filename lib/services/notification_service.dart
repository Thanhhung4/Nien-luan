import 'package:pocketbase/pocketbase.dart';
import 'package:myshop/models/notification.dart'; // Import model mới

class NotificationService {
  final PocketBase pb;

  NotificationService(this.pb);

  /// Lấy danh sách thông báo (mới nhất xếp trước)
  /// Dùng cho cả nhân viên và quản lý
  Future<List<NotificationModel>> getNotifications() async {
    try {
      final records = await pb
          .collection('notifications')
          .getFullList(
            sort: '-created', // Mới nhất lên đầu
          );
      return records.map((r) => NotificationModel.fromRecord(r)).toList();
    } catch (e) {
      print('NotificationService - Error fetching notifications: $e');
      throw Exception('Failed to load notifications: $e');
    }
  }

  /// Tạo một thông báo mới (chỉ dùng cho Quản lý)
  Future<void> createNotification({
    required String title,
    required String content,
  }) async {
    try {
      await pb
          .collection('notifications')
          .create(body: {'title': title, 'content': content});
    } catch (e) {
      print('NotificationService - Error creating notification: $e');
      throw Exception('Failed to create notification: $e');
    }
  }
}
