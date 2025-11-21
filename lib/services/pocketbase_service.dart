// [DÁN TOÀN BỘ CODE NÀY VÀO lib/services/pocketbase_service.dart]

import 'package:pocketbase/pocketbase.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:myshop/models/table.dart';
import 'package:myshop/models/menu_item.dart';
import 'package:myshop/models/order.dart';
import 'package:myshop/models/order_item_view.dart';
import 'notification_service.dart';
import 'schedule_service.dart';
// Import các service con
import 'auth_service.dart';
import 'user_service.dart';
import 'menu_service.dart';
import 'report_service.dart';
import 'inventory_service.dart';
// Import các view model
import 'package:myshop/models/order_view.dart';

class PocketBaseService {
  // --- Singleton Pattern ---
  static final PocketBaseService _instance = PocketBaseService._internal();
  factory PocketBaseService() => _instance;
  static PocketBaseService get instance => _instance;

  final PocketBase pb;
  // --- Các service con ---
  late final AuthService auth;
  late final UserService users;
  late final MenuService menu;
  late final NotificationService notifications;
  late final ScheduleService schedules;
  late final ReportService reports;
  late final InventoryService inventory;

  PocketBaseService._internal()
    // Lấy URL từ .env, fallback về localhost
    : pb = PocketBase(dotenv.env['POCKETBASE_URL'] ?? 'http://127.0.0.1:8091') {
    // Khởi tạo service con
    auth = AuthService(pb);
    users = UserService(pb);
    menu = MenuService(pb);
    notifications = NotificationService(pb);
    schedules = ScheduleService(pb);
    reports = ReportService(pb);
    inventory = InventoryService(pb);
  }
  // --- Hết phần Singleton ---

  // --- Chức Năng Xác Thực ---
  Future<bool> login(String email, String password) async {
    return auth.login(email, password);
  }

  String getRole() {
    return auth.getRole();
  }

  void logout() {
    auth.logout();
  }

  // --- Chức Năng Quản Lý Bàn ---
  Future<List<TableModel>> getTables() async {
    try {
      final records = await pb.collection('tables').getFullList();
      final tables = records
          .map((record) => TableModel.fromRecord(record))
          .toList();
      tables.sort((a, b) {
        final numA = _extractTableNumber(a.name);
        final numB = _extractTableNumber(b.name);
        return numA.compareTo(numB);
      });
      return tables;
    } catch (e) {
      print('Error fetching tables: $e');
      throw Exception('Failed to load tables: $e');
    }
  }

  Future<void> updateTableStatus(String tableId, String newStatus) async {
    try {
      await pb
          .collection('tables')
          .update(tableId, body: {'status': newStatus});
    } catch (e) {
      print('Error updating table status: $e');
      throw Exception('Failed to update table: $e');
    }
  }

  // --- Chức Năng Tạo Hóa Đơn Mới ---
  Future<String> createOrderRecord(double totalPrice, {String? tableId}) async {
    try {
      final body = {
        'total_price': totalPrice,
        'created_by': pb.authStore.record?.id,
      };
      if (tableId != null && tableId.isNotEmpty) {
        body['table'] = tableId;
      }

      final record = await pb.collection('orders').create(body: body);
      return record.id;
    } catch (e) {
      print('Error creating order record: $e');
      throw Exception('Failed to create order record: $e');
    }
  }

  Future<void> createOrderItemRecord({
    required String orderId,
    required String menuItemId,
    required int quantity,
    required double price,
    String? notes,
  }) async {
    try {
      await pb
          .collection('order_items')
          .create(
            body: {
              'order': orderId,
              'menu_item': menuItemId,
              'quantity': quantity,
              'price': price,
              'notes': notes,
            },
          );
    } catch (e) {
      print('Error creating order item record: $e');
      throw Exception('Failed to create order item record: $e');
    }
  }

  // --- CÁC HÀM CHO LOGIC BÀN ĐÃ CÓ KHÁCH ---

  Future<OrderModel?> getPendingOrderForTable(String tableId) async {
    try {
      final record = await pb
          .collection('orders')
          .getFirstListItem('table = "$tableId"');
      return OrderModel.fromRecord(record);
    } on ClientException catch (e) {
      if (e.statusCode == 404) {
        return null;
      }
      throw Exception('Error fetching pending order: $e');
    } catch (e) {
      throw Exception('Error fetching pending order: $e');
    }
  }

  Future<List<OrderItemView>> getOrderItemsWithDetails(String orderId) async {
    try {
      final records = await pb
          .collection('order_items')
          .getFullList(filter: 'order = "$orderId"', expand: 'menu_item');

      return records.map((record) {
        final notes = record.getStringValue('notes');
        final expandedData = record.get<List<RecordModel>>('expand.menu_item');

        if (expandedData.isEmpty) {
          final fakeRecord = RecordModel({
            'id': 'deleted',
            'collectionId': 'menu_items',
            'created': DateTime.now().toIso8601String(),
            'updated': DateTime.now().toIso8601String(),
            'name': 'Món đã bị xóa',
            'price': record.getDoubleValue('price'),
            'category': 'food',
            'image': '',
            'in_stock': false,
            'unit': '',
            'description': '',
            'cost': 0.0,
          });

          final deletedMenuItem = MenuItemModel.fromRecord(fakeRecord, pb);

          return OrderItemView(
            id: record.id,
            quantity: record.getIntValue('quantity'),
            price: record.getDoubleValue('price'),
            menuItem: deletedMenuItem,
            notes: notes,
          );
        }

        final menuItemRecord = expandedData.first;
        final menuItem = MenuItemModel.fromRecord(menuItemRecord, pb);

        return OrderItemView(
          id: record.id,
          quantity: record.getIntValue('quantity'),
          price: record.getDoubleValue('price'),
          menuItem: menuItem,
          notes: notes,
        );
      }).toList();
    } catch (e) {
      print('Error fetching order items: $e');
      throw Exception('Failed to load order items: $e');
    }
  }

  // --- SỬA HÀM NÀY (TẠM THỜI VÔ HIỆU HÓA TRỪ KHO) ---
  Future<void> checkoutOrder(String orderId, String tableId) async {
    try {
      // Chuyển bàn về "trống"
      await pb.collection('tables').update(tableId, body: {'status': 'empty'});

      // 3. (MỚI) Tự động trừ kho
      // Lấy danh sách các món trong đơn hàng vừa thanh toán
      final itemsInOrder = await getOrderItemsWithDetails(orderId);

      // --- SỬA LỖI: TẠM THỜI ẨN DÒNG NÀY ĐI ---
      inventory.deductStockForOrder(itemsInOrder);
      // --- KẾT THÚC SỬA LỖI ---
    } catch (e) {
      print('Error during checkout: $e');
      throw Exception('Failed to process checkout: $e');
    }
  }

  Future<void> updateOrderTotalPrice(
    String orderId,
    double newTotalPrice,
  ) async {
    try {
      await pb
          .collection('orders')
          .update(orderId, body: {'total_price': newTotalPrice});
    } catch (e) {
      print('Error updating order total price: $e');
      throw Exception('Failed to update order total price: $e');
    }
  }

  String _escapeFilterValue(String value) {
    return value.replaceAll("'", "''");
  }

  Future<List<OrderViewModel>> getCompletedOrders({
    DateTime? selectedDate,
    String? searchTerm,
  }) async {
    try {
      final now = DateTime.now();
      DateTime startDateTimeLocal;
      DateTime endDateTimeLocal;
      if (selectedDate != null) {
        startDateTimeLocal = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
        );
        endDateTimeLocal = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          23,
          59,
          59,
        );
      } else {
        final thirtyDaysAgo = now.subtract(const Duration(days: 30));
        startDateTimeLocal = DateTime(
          thirtyDaysAgo.year,
          thirtyDaysAgo.month,
          thirtyDaysAgo.day,
        );
        endDateTimeLocal = DateTime(now.year, now.month, now.day, 23, 59, 59);
      }
      final startFilter = startDateTimeLocal.toUtc().toIso8601String();
      final endFilter = endDateTimeLocal.toUtc().toIso8601String();

      List<String> filters = [
        'created >= \'$startFilter\'',
        'created <= \'$endFilter\'',
      ];

      if (searchTerm != null && searchTerm.isNotEmpty) {
        final escapedTerm = _escapeFilterValue(searchTerm);
        filters.add('id ~ \'$escapedTerm\'');
      }

      final filterString = filters.join(' && ');

      final records = await pb
          .collection('orders')
          .getFullList(
            filter: filterString,
            sort: '-created',
            expand: 'created_by',
          );

      print('Found ${records.length} paid orders');

      return records.map((record) {
        RecordModel? tableRecord;
        // Thử lấy table record nếu có, không expand vì có thể null
        final tableId = record.getStringValue('table');
        if (tableId.isNotEmpty) {
          try {
            // Có thể cần lấy table riêng nếu cần
          } catch (e) {
            print('Could not fetch table for order ${record.id}: $e');
          }
        }

        RecordModel? creatorRecord;
        final creatorExpand = record.get<List<RecordModel>>(
          'expand.created_by',
        );
        if (creatorExpand.isNotEmpty) {
          creatorRecord = creatorExpand.first;
        }
        return OrderViewModel.fromRecord(record, tableRecord, creatorRecord);
      }).toList();
    } catch (e) {
      print('Error fetching completed orders: $e');
      throw Exception('Failed to load completed orders: $e');
    }
  }

  int _extractTableNumber(String name) {
    final match = RegExp(r'\d+').firstMatch(name);
    if (match != null) {
      return int.tryParse(match.group(0)!) ?? 0;
    }
    return 0;
  }
}
