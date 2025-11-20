import 'package:pocketbase/pocketbase.dart';

// Enum này định nghĩa quyền TRUY CẬP APP
enum UserRole {
  employee,
  manager;

  static UserRole fromString(String? roleString) {
    switch (roleString) {
      case 'employee':
        return UserRole.employee;
      case 'manager':
        return UserRole.manager;
      default:
        return UserRole.employee;
    }
  }

  String toJson() => name;
  String get display {
    switch (this) {
      case UserRole.employee:
        return 'Nhân viên';
      case UserRole.manager:
        return 'Quản lý';
    }
  }
}

// Model này chỉ đại diện cho Collection 'users' (Bảng xác thực)
class User {
  final String id;
  final String email;
  final String name; // 'name' trong 'users' thường là tên hiển thị/nick name
  final UserRole role; // 'role' trong 'users' là 'manager' hoặc 'employee'

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
  });

  factory User.fromRecord(RecordModel record) {
    return User(
      id: record.id,
      email: record.getStringValue('email'),
      name: record.getStringValue('name'),
      role: UserRole.fromString(record.getStringValue('role')),
    );
  }
}
