// [DÁN TOÀN BỘ CODE NÀY VÀO lib/services/menu_service.dart]

import 'dart:io';
import 'package:pocketbase/pocketbase.dart';
import 'package:myshop/models/menu_item.dart';
import 'package:http/http.dart' as http;

class MenuService {
  final PocketBase pb;

  MenuService(this.pb);

  /// 1. LẤY (READ) TẤT CẢ
  Future<List<MenuItemModel>> getMenu() async {
    try {
      final records = await pb
          .collection('menu_items')
          .getFullList(sort: 'category,-created');
      return records
          .map((record) => MenuItemModel.fromRecord(record, pb))
          .toList();
    } catch (e) {
      print('MenuService - getMenu Error: $e');
      throw Exception('Failed to load menu: $e');
    }
  }

  // --- HÀM MỚI (ĐỂ TẢI LẠI GIÁ VỐN) ---
  /// 2. LẤY (READ) MỘT MÓN
  Future<MenuItemModel> getMenuItem(String id) async {
    try {
      final record = await pb.collection('menu_items').getOne(id);
      return MenuItemModel.fromRecord(record, pb);
    } catch (e) {
      print('MenuService - getMenuItem Error: $e');
      throw Exception('Failed to load menu item: $e');
    }
  }

  /// 3. THÊM (CREATE) - (ĐÃ SỬA)
  Future<void> createMenuItem({
    required String name,
    required double price,
    required String category,
    required bool inStock,
    required String unit,
    required String description,
    File? image,
    double cost = 0.0, // <-- Thêm trường cost
  }) async {
    try {
      final body = <String, dynamic>{
        'name': name,
        'price': price,
        'category': category,
        'in_stock': inStock,
        'unit': unit,
        'description': description,
        'cost': cost, // <-- Thêm cost vào body
      };

      http.MultipartFile? imageFile;
      if (image != null) {
        imageFile = await http.MultipartFile.fromPath('image', image.path);
      }

      await pb
          .collection('menu_items')
          .create(
            body: body,
            // --- SỬA LỖI Ở ĐÂY ---
            files: imageFile != null ? [imageFile] : [], // Dùng [] thay vì null
          );
    } catch (e) {
      print('MenuService - createMenuItem Error: $e');
      throw Exception('Failed to create menu item: $e');
    }
  }

  /// 4. SỬA (UPDATE) - (ĐÃ SỬA)
  Future<void> updateMenuItem({
    required String id,
    required String name,
    required double price,
    required String category,
    required bool inStock,
    required String unit,
    required String description,
    File? image,
    String? currentImageFilename,
    double cost = 0.0, // <-- Thêm trường cost
  }) async {
    try {
      final body = <String, dynamic>{
        'name': name,
        'price': price,
        'category': category,
        'in_stock': inStock,
        'unit': unit,
        'description': description,
        'cost': cost, // <-- Thêm cost vào body
      };

      http.MultipartFile? imageFile;
      if (image != null) {
        // Nếu có ảnh mới, chuẩn bị ảnh mới
        imageFile = await http.MultipartFile.fromPath('image', image.path);
      } else if (currentImageFilename == null || currentImageFilename.isEmpty) {
        // Nếu không có ảnh mới VÀ không có ảnh cũ -> Xóa ảnh
        body['image'] = null;
      }

      await pb
          .collection('menu_items')
          .update(
            id,
            body: body,
            // --- SỬA LỖI Ở ĐÂY ---
            files: imageFile != null ? [imageFile] : [], // Dùng [] thay vì null
          );
    } catch (e) {
      print('MenuService - updateMenuItem Error: $e');
      throw Exception('Failed to update menu item: $e');
    }
  }

  /// 5. XÓA (DELETE)
  Future<void> deleteMenuItem(String id) async {
    try {
      await pb.collection('menu_items').delete(id);
    } catch (e) {
      print('MenuService - deleteMenuItem Error: $e');
      throw Exception('Failed to delete menu item: $e');
    }
  }
}
