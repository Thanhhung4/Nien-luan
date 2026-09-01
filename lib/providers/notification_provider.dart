import 'package:flutter/foundation.dart';

// Notification Type Enum
enum NotificationType {
  order, // Thông báo liên quan đơn hàng
  staff, // Thông báo nhân viên
  inventory, // Thông báo kho
  system, // Thông báo hệ thống
  alert, // Cảnh báo
  info, // Thông tin chung
}

// Notification Priority
enum NotificationPriority { low, normal, high, urgent }

// Model for individual notification
class AppNotification {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final NotificationPriority priority;
  final DateTime timestamp;
  bool isRead;
  String? actionId; // ID để navigate hoặc perform action
  String? actionLabel; // Label cho action button
  int? duration; // Duration in seconds for snackbar

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.priority = NotificationPriority.normal,
    required this.timestamp,
    this.isRead = false,
    this.actionId,
    this.actionLabel,
    this.duration,
  });

  // Copy with for easy updates
  AppNotification copyWith({bool? isRead, String? actionId}) {
    return AppNotification(
      id: id,
      title: title,
      message: message,
      type: type,
      priority: priority,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
      actionId: actionId ?? this.actionId,
      actionLabel: actionLabel,
      duration: duration,
    );
  }
}

class NotificationProvider extends ChangeNotifier {
  // State variables
  final List<AppNotification> _notifications = [];
  final List<AppNotification> _displayQueue = [];
  final Map<NotificationType, bool> _typeSettings = {
    NotificationType.order: true,
    NotificationType.staff: true,
    NotificationType.inventory: true,
    NotificationType.system: true,
    NotificationType.alert: true,
    NotificationType.info: true,
  };

  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _quietHoursActive = false;
  String _quietHoursStart = '22:00';
  String _quietHoursEnd = '06:00';

  final int _maxNotificationsStored = 100;

  // Getters
  List<AppNotification> get notifications => _notifications;
  List<AppNotification> get displayQueue => _displayQueue;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  bool get hasUnread => unreadCount > 0;
  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  bool get quietHoursActive => _quietHoursActive;
  String get quietHoursStart => _quietHoursStart;
  String get quietHoursEnd => _quietHoursEnd;

  // Get notifications by type
  List<AppNotification> getNotificationsByType(NotificationType type) {
    return _notifications.where((n) => n.type == type).toList();
  }

  // Get unread notifications by type
  List<AppNotification> getUnreadByType(NotificationType type) {
    return _notifications.where((n) => n.type == type && !n.isRead).toList();
  }

  // Get recent notifications
  List<AppNotification> getRecentNotifications({int limit = 10}) {
    return _notifications.take(limit).toList();
  }

  /// Add notification to system
  void addNotification({
    required String title,
    required String message,
    required NotificationType type,
    NotificationPriority priority = NotificationPriority.normal,
    String? actionId,
    String? actionLabel,
    int? duration,
  }) {
    // Check if notification type is enabled
    if (!_typeSettings[type]!) {
      return;
    }

    // Check quiet hours
    if (_quietHoursActive && !_shouldShowInQuietHours(priority)) {
      debugPrint('Notification suppressed during quiet hours: $title');
      return;
    }

    final notification = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      message: message,
      type: type,
      priority: priority,
      timestamp: DateTime.now(),
      isRead: false,
      actionId: actionId,
      actionLabel: actionLabel,
      duration: duration ?? _getDefaultDuration(priority),
    );

    // Add to notifications list
    _notifications.insert(0, notification);

    // Add to display queue for immediate display
    _displayQueue.insert(0, notification);

    // Maintain max stored notifications
    if (_notifications.length > _maxNotificationsStored) {
      _notifications.removeLast();
    }

    // Trigger sound/vibration if enabled
    _playNotificationSignal(priority);

    debugPrint('Notification added: ${notification.title}');
    debugPrint(
      'Total notifications: ${_notifications.length}, Unread: $unreadCount',
    );
    notifyListeners();
    debugPrint('notifyListeners() called');
  }

  /// Quick add methods for common notification types
  void addOrderNotification(String message, {String? actionId}) {
    addNotification(
      title: 'Đơn hàng',
      message: message,
      type: NotificationType.order,
      priority: NotificationPriority.high,
      actionId: actionId,
      actionLabel: 'Xem',
    );
  }

  void addStaffNotification(String message, {String? actionId}) {
    addNotification(
      title: 'Nhân viên',
      message: message,
      type: NotificationType.staff,
      actionId: actionId,
    );
  }

  void addInventoryNotification(String message, {String? actionId}) {
    addNotification(
      title: 'Kho hàng',
      message: message,
      type: NotificationType.inventory,
      priority: NotificationPriority.normal,
      actionId: actionId,
    );
  }

  void addSystemNotification(String message) {
    addNotification(
      title: 'Thông báo hệ thống',
      message: message,
      type: NotificationType.system,
      priority: NotificationPriority.low,
    );
  }

  void addAlertNotification(String title, String message) {
    addNotification(
      title: title,
      message: message,
      type: NotificationType.alert,
      priority: NotificationPriority.urgent,
    );
  }

  /// Mark notification as read
  void markAsRead(String notificationId) {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      notifyListeners();
    }
  }

  /// Mark all notifications as read
  void markAllAsRead() {
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
    notifyListeners();
  }

  /// Mark all notifications of specific type as read
  void markTypeAsRead(NotificationType type) {
    for (int i = 0; i < _notifications.length; i++) {
      if (_notifications[i].type == type) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
      }
    }
    notifyListeners();
  }

  /// Remove notification
  void removeNotification(String notificationId) {
    _notifications.removeWhere((n) => n.id == notificationId);
    _displayQueue.removeWhere((n) => n.id == notificationId);
    notifyListeners();
  }

  /// Clear all notifications
  void clearAll() {
    _notifications.clear();
    _displayQueue.clear();
    notifyListeners();
  }

  /// Clear notifications of specific type
  void clearByType(NotificationType type) {
    _notifications.removeWhere((n) => n.type == type);
    _displayQueue.removeWhere((n) => n.type == type);
    notifyListeners();
  }

  /// Clear old notifications (older than X days)
  void clearOldNotifications({int olderThanDays = 7}) {
    final cutoffTime = DateTime.now().subtract(Duration(days: olderThanDays));
    _notifications.removeWhere((n) => n.timestamp.isBefore(cutoffTime));
    _displayQueue.removeWhere((n) => n.timestamp.isBefore(cutoffTime));
    notifyListeners();
  }

  /// Pop next notification from display queue
  AppNotification? popNextDisplay() {
    if (_displayQueue.isEmpty) {
      return null;
    }
    return _displayQueue.removeAt(0);
  }

  /// Check if display queue has pending notifications
  bool get hasQueuedNotifications => _displayQueue.isNotEmpty;

  /// Set notification type enabled/disabled
  void setTypeEnabled(NotificationType type, bool enabled) {
    _typeSettings[type] = enabled;
    notifyListeners();
  }

  /// Toggle sound
  void toggleSound() {
    _soundEnabled = !_soundEnabled;
    notifyListeners();
  }

  /// Toggle vibration
  void toggleVibration() {
    _vibrationEnabled = !_vibrationEnabled;
    notifyListeners();
  }

  /// Set quiet hours
  void setQuietHours({
    required String startTime, // Format: HH:mm
    required String endTime,
    required bool active,
  }) {
    _quietHoursStart = startTime;
    _quietHoursEnd = endTime;
    _quietHoursActive = active;
    notifyListeners();
  }

  /// Check if should show notification despite quiet hours
  bool _shouldShowInQuietHours(NotificationPriority priority) {
    // Urgent and high priority notifications show even in quiet hours
    return priority == NotificationPriority.urgent ||
        priority == NotificationPriority.high;
  }

  /// Get default duration based on priority
  int _getDefaultDuration(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.urgent:
        return 10; // 10 seconds
      case NotificationPriority.high:
        return 6;
      case NotificationPriority.normal:
        return 4;
      case NotificationPriority.low:
        return 3;
    }
  }

  /// Play notification signal (sound/vibration)
  void _playNotificationSignal(NotificationPriority priority) {
    // TODO: Implement actual sound and vibration using plugins
    // Example: await Vibration.vibrate(duration: 100);
    // Example: await AudioPlayer().play(...);

    if (_vibrationEnabled) {
      debugPrint('Vibration triggered for priority: ${priority.toString()}');
    }
    if (_soundEnabled) {
      debugPrint('Sound triggered for priority: ${priority.toString()}');
    }
  }

  /// Get notification statistics
  Map<String, dynamic> getStatistics() {
    return {
      'totalNotifications': _notifications.length,
      'unreadCount': unreadCount,
      'byType': {
        for (var type in NotificationType.values)
          type.toString(): getNotificationsByType(type).length,
      },
      'byPriority': {
        'urgent': _notifications
            .where((n) => n.priority == NotificationPriority.urgent)
            .length,
        'high': _notifications
            .where((n) => n.priority == NotificationPriority.high)
            .length,
        'normal': _notifications
            .where((n) => n.priority == NotificationPriority.normal)
            .length,
        'low': _notifications
            .where((n) => n.priority == NotificationPriority.low)
            .length,
      },
    };
  }

  /// Clear error messages (convenience method)
  void clearErrorNotifications() {
    clearByType(NotificationType.alert);
  }
}
