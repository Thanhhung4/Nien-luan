import 'package:flutter/foundation.dart';
import '../models/staff_profile.dart';
import '../services/pocketbase_service.dart';

// User Role Enum
enum UserRole { admin, manager, waiter, chef, cashier, staff }

// Work Status Enum
enum WorkStatus { available, busy, break_time, offline }

class UserProvider extends ChangeNotifier {
  final PocketBaseService _pbService = PocketBaseService.instance;

  // State variables
  List<StaffProfile> _allStaff = [];
  List<StaffProfile> _activeStaff = [];
  Map<String, WorkStatus> _staffWorkStatus = {};
  bool _isLoading = false;
  String? _error;

  // Current user state
  StaffProfile? _currentUser;
  UserRole? _currentUserRole;
  WorkStatus _currentWorkStatus = WorkStatus.offline;

  // Getters
  List<StaffProfile> get allStaff => _allStaff;
  List<StaffProfile> get activeStaff => _activeStaff;
  bool get isLoading => _isLoading;
  String? get error => _error;
  StaffProfile? get currentUser => _currentUser;
  UserRole? get currentUserRole => _currentUserRole;
  WorkStatus get currentWorkStatus => _currentWorkStatus;

  // Filter staff by role
  List<StaffProfile> get waiters =>
      _activeStaff.where((staff) => staff.role == 'waiter').toList();

  List<StaffProfile> get chefs =>
      _activeStaff.where((staff) => staff.role == 'chef').toList();

  List<StaffProfile> get cashiers =>
      _activeStaff.where((staff) => staff.role == 'cashier').toList();

  List<StaffProfile> get managers =>
      _activeStaff.where((staff) => staff.role == 'manager').toList();

  // Statistics
  int get totalStaffCount => _allStaff.length;
  int get activeStaffCount => _activeStaff.length;
  int get availableStaffCount => _activeStaff
      .where((staff) => _staffWorkStatus[staff.id] == WorkStatus.available)
      .length;

  /// Initialize user provider
  UserProvider() {
    _initializeCurrentUser();
  }

  void _initializeCurrentUser() {
    // Get current user from auth provider
    final authStore = _pbService.pb.authStore;
    if (authStore.isValid && authStore.record != null) {
      _currentUserRole = _parseUserRole(
        authStore.record?.getStringValue('role'),
      );
      _loadCurrentUserProfile();
    }
  }

  /// Load all staff profiles
  Future<void> loadAllStaff() async {
    _setLoading(true);
    try {
      // TODO: Implement actual service call
      // _allStaff = await _pbService.getAllStaffProfiles();
      _allStaff = []; // Temporary placeholder
      _updateActiveStaffList();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  /// Load current user profile
  Future<void> _loadCurrentUserProfile() async {
    try {
      final userId = _pbService.pb.authStore.record?.id;
      if (userId != null) {
        // TODO: Implement actual service call
        // _currentUser = await _pbService.getStaffProfile(userId);
        _currentUser = null; // Temporary placeholder
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Update staff work status
  Future<bool> updateWorkStatus(String staffId, WorkStatus status) async {
    try {
      // TODO: Implement actual service call
      // final success = await _pbService.updateStaffWorkStatus(staffId, status);
      final success = true; // Temporary placeholder

      if (success) {
        _staffWorkStatus[staffId] = status;
        if (staffId == _currentUser?.id) {
          _currentWorkStatus = status;
        }
        _updateActiveStaffList();
        notifyListeners();
      }
      return success;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  /// Update current user work status
  Future<bool> updateCurrentWorkStatus(WorkStatus status) async {
    if (_currentUser != null) {
      return await updateWorkStatus(_currentUser!.id, status);
    }
    return false;
  }

  /// Check if user has specific role permission
  bool hasPermission(String permission) {
    if (_currentUserRole == null) return false;

    switch (_currentUserRole!) {
      case UserRole.admin:
        return true; // Admin has all permissions
      case UserRole.manager:
        return [
          'manage_staff',
          'view_reports',
          'manage_menu',
          'manage_orders',
        ].contains(permission);
      case UserRole.waiter:
        return [
          'take_orders',
          'serve_orders',
          'view_menu',
        ].contains(permission);
      case UserRole.chef:
        return [
          'view_orders',
          'update_order_status',
          'manage_kitchen',
        ].contains(permission);
      case UserRole.cashier:
        return [
          'process_payment',
          'view_orders',
          'generate_receipts',
        ].contains(permission);
      case UserRole.staff:
        return ['view_menu'].contains(permission);
    }
  }

  /// Get staff by ID
  StaffProfile? getStaffById(String staffId) {
    try {
      return _allStaff.firstWhere((staff) => staff.id == staffId);
    } catch (e) {
      return null;
    }
  }

  /// Search staff by name
  List<StaffProfile> searchStaff(String query) {
    if (query.isEmpty) return _allStaff;

    return _allStaff.where((staff) {
      final name = staff.name.toLowerCase();
      final email = staff.email.toLowerCase();
      final searchQuery = query.toLowerCase();

      return name.contains(searchQuery) || email.contains(searchQuery);
    }).toList();
  }

  /// Get staff by role
  List<StaffProfile> getStaffByRole(String role) {
    return _allStaff.where((staff) => staff.role == role).toList();
  }

  /// Get staff work status
  WorkStatus getStaffWorkStatus(String staffId) {
    return _staffWorkStatus[staffId] ?? WorkStatus.offline;
  }

  /// Check if staff is available
  bool isStaffAvailable(String staffId) {
    return _staffWorkStatus[staffId] == WorkStatus.available;
  }

  /// Get available staff by role
  List<StaffProfile> getAvailableStaffByRole(String role) {
    return getStaffByRole(
      role,
    ).where((staff) => isStaffAvailable(staff.id)).toList();
  }

  /// Update staff profile
  Future<bool> updateStaffProfile(StaffProfile profile) async {
    try {
      // TODO: Implement actual service call
      // final success = await _pbService.updateStaffProfile(profile);
      final success = true; // Temporary placeholder

      if (success) {
        // Update local state
        final index = _allStaff.indexWhere((staff) => staff.id == profile.id);
        if (index != -1) {
          _allStaff[index] = profile;
        }

        if (profile.id == _currentUser?.id) {
          _currentUser = profile;
        }

        _updateActiveStaffList();
        notifyListeners();
      }
      return success;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  /// Refresh staff data
  Future<void> refreshStaff() async {
    await loadAllStaff();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Logout current user
  void logoutUser() {
    _currentUser = null;
    _currentUserRole = null;
    _currentWorkStatus = WorkStatus.offline;
    notifyListeners();
  }

  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _updateActiveStaffList() {
    _activeStaff = _allStaff
        .where((staff) => _staffWorkStatus[staff.id] != WorkStatus.offline)
        .toList();
    notifyListeners();
  }

  UserRole? _parseUserRole(String? roleString) {
    if (roleString == null) return null;

    switch (roleString.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'manager':
        return UserRole.manager;
      case 'waiter':
        return UserRole.waiter;
      case 'chef':
        return UserRole.chef;
      case 'cashier':
        return UserRole.cashier;
      case 'staff':
        return UserRole.staff;
      default:
        return UserRole.staff;
    }
  }
}
