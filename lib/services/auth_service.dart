// [DÁN TOÀN BỘ CODE NÀY VÀO lib/services/auth_service.dart]

import 'package:pocketbase/pocketbase.dart';
import 'package:flutter/foundation.dart';
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
    } on ClientException catch (e) {
      print('Login failed: $e');

      final msg = e.toString();
      final isAndroid =
          !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
      final isLocalhost =
          msg.contains('http://127.0.0.1:8091') ||
          msg.contains('address = 127.0.0.1') ||
          msg.contains('uri=http://127.0.0.1:8091');
      final isConnRefused = msg.contains('Connection refused');

      if (isAndroid && isLocalhost && isConnRefused) {
        print(
          'Gợi ý: Bạn đang chạy trên MÁY THẬT Android nhưng gọi PocketBase ở 127.0.0.1.\n'
          'Hãy bật USB port forwarding: adb reverse tcp:8091 tcp:8091 (rồi thử login lại).',
        );
      }

      return false; // Trả về false khi lỗi
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
