// Enum này sẽ định nghĩa vai trò công việc
enum StaffRole {
  employee, // Nhân viên phục vụ (có thể đăng nhập)
  chef, // Đầu bếp (không cần đăng nhập)
  cleaner, // Vệ sinh (không cần đăng nhập)
  security; // Bảo vệ (không cần đăng nhập)

  static StaffRole fromString(String? roleString) {
    switch (roleString) {
      case 'employee':
        return StaffRole.employee;
      case 'chef':
        return StaffRole.chef;
      case 'cleaner':
        return StaffRole.cleaner;
      case 'security':
        return StaffRole.security;
      default:
        return StaffRole.employee; // Mặc định
    }
  }

  // Chuyển thành chuỗi để lưu vào PocketBase
  String toJson() {
    return name; // 'manager', 'employee', 'chef', v.v.
  }

  // Chuyển thành chuỗi tiếng Việt để hiển thị
  String get display {
    switch (this) {
      case StaffRole.employee:
        return 'Nhân viên';
      case StaffRole.chef:
        return 'Đầu bếp';
      case StaffRole.cleaner:
        return 'Vệ sinh';
      case StaffRole.security:
        return 'Bảo vệ';
    }
  }

  // Hàm kiểm tra xem vai trò này có cần tài khoản đăng nhập không
  bool get needsLoginAccount {
    switch (this) {
      case StaffRole.employee:
        return true; // Chỉ Quản lý và Nhân viên mới cần đăng nhập
      default:
        return false; // Chef, Cleaner, Security không cần
    }
  }
}
