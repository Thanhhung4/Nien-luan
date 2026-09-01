// [DÁN TOÀN BỘ CODE NÀY VÀO lib/services/user_service.dart]

import 'package:pocketbase/pocketbase.dart';
// Import các model mới
import 'package:myshop/models/staff_profile.dart';
import 'package:myshop/models/staff_role.dart';

class UserService {
  final PocketBase pb;

  UserService(this.pb);

  /// 1. LẤY (READ) TẤT CẢ
  Future<List<StaffProfile>> getStaffProfiles() async {
    try {
      final records = await pb
          .collection('staff_profiles')
          .getFullList(sort: 'name', expand: 'user_account');
      return records.map((record) => StaffProfile.fromRecord(record)).toList();
    } catch (e) {
      print('UserService - Error fetching staff profiles: $e');
      throw Exception('Failed to load staff list: $e');
    }
  }

  /// 2. LẤY (READ) 1 HỒ SƠ BẰNG PROFILE_ID
  Future<StaffProfile> getStaffProfile(String profileId) async {
    try {
      final record = await pb
          .collection('staff_profiles')
          .getOne(profileId, expand: 'user_account');
      return StaffProfile.fromRecord(record);
    } catch (e) {
      print('UserService - Error fetching single staff profile: $e');
      throw Exception('Không tìm thấy hồ sơ nhân viên.');
    }
  }

  /// 3. LẤY (READ) 1 HỒ SƠ BẰNG USER_ID
  Future<StaffProfile> getStaffProfileForUser(String userId) async {
    try {
      final record = await pb
          .collection('staff_profiles')
          .getFirstListItem(
            'user_account = \'$userId\'',
            expand: 'user_account',
          );
      return StaffProfile.fromRecord(record);
    } catch (e) {
      print('UserService - Error fetching single staff profile: $e');
      throw Exception('Không tìm thấy hồ sơ nhân viên.');
    }
  }

  /// 4. THÊM (CREATE)
  Future<void> addStaffProfile({
    required String name,
    required StaffRole role,
    double salary = 0.0,
    String? email,
    String? password,
  }) async {
    String? newUserId;
    try {
      if (role.needsLoginAccount) {
        if (email == null || password == null) {
          throw Exception('Email và Mật khẩu là bắt buộc cho vai trò này.');
        }
        final userRecord = await pb
            .collection('users')
            .create(
              body: {
                'email': email,
                'password': password,
                'passwordConfirm': password,
                'emailVisibility': true,
                'name': name,
                'role': role.name,
              },
            );
        newUserId = userRecord.id;
      }

      final profileBody = <String, dynamic>{
        'name': name,
        'role': role.toJson(),
        'salary': salary,
        'status': 'active',
        // --- SỬA Ở ĐÂY (thêm S) ---
        'default_schedules': {},
      };

      if (newUserId != null) {
        profileBody['user_account'] = newUserId;
      }
      await pb.collection('staff_profiles').create(body: profileBody);
    } catch (e) {
      if (newUserId != null) {
        try {
          await pb.collection('users').delete(newUserId);
        } catch (deleteError) {
          print(
            "CRITICAL ERROR: Failed to rollback user creation: $deleteError",
          );
        }
      }
      print('UserService - Error adding staff: $e');
      if (e is ClientException && e.response.containsKey('data')) {
        final errors = e.response['data'] as Map<String, dynamic>;
        if (errors.containsKey('email')) {
          throw Exception('Email đã tồn tại.');
        }
      }
      throw Exception('Failed to add staff: $e');
    }
  }

  /// 5. XÓA (DELETE)
  Future<void> deleteStaffProfile(StaffProfile profile) async {
    try {
      await pb.collection('staff_profiles').delete(profile.id);
      if (profile.hasLoginAccount) {
        await pb.collection('users').delete(profile.userId!);
      }
    } catch (e) {
      print('UserService - Error deleting staff: $e');
      throw Exception('Failed to delete staff: $e');
    }
  }

  /// 6. SỬA (UPDATE) THÔNG TIN
  Future<void> updateStaffDetails({
    required String profileId,
    required String name,
    required StaffRole role,
    required String status,
    String? userId,
    String? newEmail,
    String? newPassword,
  }) async {
    try {
      final profileBody = <String, dynamic>{
        'name': name,
        'role': role.toJson(),
        'status': status,
      };
      await pb
          .collection('staff_profiles')
          .update(profileId, body: profileBody);

      if (userId != null && (newEmail != null || newPassword != null)) {
        // Get current user data to compare email
        final currentUser = await pb.collection('users').getOne(userId);
        final currentEmail = currentUser.getStringValue('email');

        final userBody = <String, dynamic>{};
        if (newEmail != null && newEmail != currentEmail) {
          // Only update email if it's different from current email
          userBody['email'] = newEmail;
          userBody['emailVisibility'] = true;
        }
        if (newPassword != null) {
          userBody['password'] = newPassword;
          userBody['passwordConfirm'] = newPassword;
        }

        // Only update if there are changes to make
        if (userBody.isNotEmpty) {
          await pb.collection('users').update(userId, body: userBody);
        }
      }
    } catch (e) {
      print('UserService - Error updating details: $e');
      if (e is ClientException) {
        print('ClientException response: ${e.response}');

        // Check for specific error patterns
        final responseString = e.response.toString();

        // Check for email validation errors
        if (responseString.contains('email') &&
            (responseString.contains('already exists') ||
                responseString.contains('đã tồn tại') ||
                responseString.contains('duplicate'))) {
          throw Exception('Email này đã được sử dụng bởi tài khoản khác.');
        }

        // Check for user validation errors
        if (responseString.contains('user') &&
            (responseString.contains('already exists') ||
                responseString.contains('đã tồn tại'))) {
          throw Exception('Tài khoản này đã tồn tại.');
        }

        // If it's a data validation error, try to extract the field
        if (e.response.containsKey('data')) {
          final errors = e.response['data'] as Map<String, dynamic>;
          print('Error data fields: ${errors.keys.toList()}');

          // Handle specific field errors
          if (errors.containsKey('email')) {
            final emailError = errors['email'];
            print('Email error details: $emailError');
            throw Exception('Lỗi email: ${emailError.toString()}');
          }

          if (errors.containsKey('username')) {
            final usernameError = errors['username'];
            print('Username error details: $usernameError');
            throw Exception('Lỗi tên người dùng: ${usernameError.toString()}');
          }

          // Generic field error
          final firstErrorKey = errors.keys.first;
          final firstError = errors[firstErrorKey];
          throw Exception('Lỗi $firstErrorKey: ${firstError.toString()}');
        }

        // Generic PocketBase error
        throw Exception('Lỗi cập nhật: ${e.response}');
      }
      throw Exception('Failed to update staff details: $e');
    }
  }

  /// 7. SỬA (UPDATE) LỊCH CỐ ĐỊNH (SỬA LỖI KHÔNG LƯU)
  Future<void> updateStaffDefaultSchedule({
    required String profileId,
    required Map<String, List<String>> defaultSchedule,
  }) async {
    try {
      final body = <String, dynamic>{
        // --- SỬA Ở ĐÂY (thêm S) ---
        'default_schedules': defaultSchedule,
      };

      print('ĐANG LƯU LỊCH: Gửi body: $body TỚI ID: $profileId');

      await pb.collection('staff_profiles').update(profileId, body: body);

      print('LƯU LỊCH THÀNH CÔNG!');
    } catch (e) {
      print('LỖI KHI LƯU LỊCH: $e');
      throw Exception('Lỗi khi cập nhật lịch: $e');
    }
  }

  /// 8. HÀM CŨ (Vẫn cần)
  Future<void> updateUserPassword({
    required String userId,
    required String oldPassword,
    required String newPassword,
    required String newPasswordConfirm,
  }) async {
    try {
      final body = <String, dynamic>{
        'oldPassword': oldPassword,
        'password': newPassword,
        'passwordConfirm': newPasswordConfirm,
      };
      await pb.collection('users').update(userId, body: body);
    } catch (e) {
      print('UserService - Error updating password: $e');
      if (e is ClientException && e.response.containsKey('data')) {
        final errors = e.response['data'] as Map<String, dynamic>;
        if (errors.containsKey('oldPassword')) {
          throw Exception('Mật khẩu cũ không chính xác.');
        }
      }
      throw Exception('Failed to update password: $e');
    }
  }

  /// 9. HÀM CŨ (Vẫn cần)
  Future<void> updateUserAndProfileName({
    required String userId,
    required String profileId,
    required String newName,
  }) async {
    try {
      await pb.collection('users').update(userId, body: {'name': newName});
      await pb
          .collection('staff_profiles')
          .update(profileId, body: {'name': newName});
    } catch (e) {
      print('UserService - Error updating name: $e');
      throw Exception('Failed to update name: $e');
    }
  }
}
