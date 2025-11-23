import 'package:pocketbase/pocketbase.dart';

class NotificationModel {
  final String id;
  final String title;
  final String content;
  final bool isRead;
  final DateTime created;

  NotificationModel({
    required this.id,
    required this.title,
    required this.content,
    this.isRead = false,
    required this.created,
  });

  factory NotificationModel.fromRecord(RecordModel record) {
    return NotificationModel(
      id: record.id,
      title: record.getStringValue('title'),
      content: record.getStringValue('content'),
      isRead: record.getBoolValue('isRead'),
      created: DateTime.parse(record.getStringValue('created')).toLocal(),
    );
  }
}
