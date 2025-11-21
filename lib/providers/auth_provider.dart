import 'package:flutter/foundation.dart';
import '../services/pocketbase_service.dart';

class AuthProvider extends ChangeNotifier {
  final PocketBaseService _pbService = PocketBaseService.instance;
  bool _isAuthenticated = false;
  String? _userEmail;
  String? _userId;
  String? _userRole;

  bool get isAuthenticated => _isAuthenticated;
  String? get userEmail => _userEmail;
  String? get userId => _userId;
  String? get userRole => _userRole;

  // Khởi tạo và check auth state hiện tại
  AuthProvider() {
    _checkAuthState();
  }

  void _checkAuthState() {
    if (_pbService.pb.authStore.isValid) {
      _isAuthenticated = true;
      _userEmail = _pbService.pb.authStore.record?.getStringValue('email');
      _userId = _pbService.pb.authStore.record?.id;
      _userRole = _pbService.pb.authStore.record?.getStringValue('role');
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      final success = await _pbService.login(email, password);
      if (success) {
        _isAuthenticated = true;
        _userEmail = _pbService.pb.authStore.record?.getStringValue('email');
        _userId = _pbService.pb.authStore.record?.id;
        _userRole = _pbService.pb.authStore.record?.getStringValue('role');
        notifyListeners();
      }
      return success;
    } catch (e) {
      return false;
    }
  }

  Future<void> logout() async {
    _pbService.logout();
    _isAuthenticated = false;
    _userEmail = null;
    _userId = null;
    _userRole = null;
    notifyListeners();
  }
}
