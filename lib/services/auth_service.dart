// [DÁN TOÀN BỘ CODE NÀY VÀO lib/services/auth_service.dart]

import 'package:pocketbase/pocketbase.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart'; // <-- Không cần nữa

class AuthService {
  // --- SỬA 1: XÓA DÒNG TỰ TẠO PB ---
  // final pb = PocketBase(
  //   dotenv.env['POCKETBASE_URL'] ?? 'http://127.0.0.1:8090',
  // );

  // --- SỬA 2: THÊM BIẾN ĐỂ NHẬN PB TỪ BÊN NGOÀI ---
  final PocketBase pb;

  // --- SỬA 3: THÊM CONSTRUCTOR ĐỂ NHẬN PB ---
  AuthService(this.pb);

  // Login user với email/password
  Future<bool> login(String email, String password) async {
    try {
      await pb.collection('users').authWithPassword(email, password);
      print('Login success: ${pb.authStore.record?.id}');
      return true;
    } catch (e) {
      print('Login failed: $e');
      return false; // Trả về false khi lỗi
    }
  }

  // Logout user
  void logout() {
    pb.authStore.clear();
  }

  // Kiểm tra user đã login chưa
  bool get isLoggedIn => pb.authStore.isValid;

  // --- SỬA 4: THÊM HÀM getRole() BỊ THIẾU ---
  String getRole() {
    return pb.authStore.record?.getStringValue('role') ?? '';
  }
}
