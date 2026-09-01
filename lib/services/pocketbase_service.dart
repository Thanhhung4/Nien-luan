// [DÁN TOÀN BỘ CODE NÀY VÀO lib/services/pocketbase_service.dart]

import 'package:flutter/foundation.dart';
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

String _defaultPocketBaseUrl() {
  if (kIsWeb) {
    return 'http://127.0.0.1:8091';
  }

  // Android emulator: 10.0.2.2 maps to the host machine (your PC).
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8091';
  }

  return 'http://127.0.0.1:8091';
}

String _resolvePocketBaseUrl() {
  final raw = dotenv.env['POCKETBASE_URL']?.trim();
  if (raw == null || raw.isEmpty) {
    return _defaultPocketBaseUrl();
  }

  final uri = Uri.tryParse(raw);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return _defaultPocketBaseUrl();
  }

  // 0.0.0.0 is a bind-all interface address (server-side), not a client address.
  if (uri.host == '0.0.0.0') {
    return _defaultPocketBaseUrl();
  }

  return raw;
}

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
    // Lấy URL từ .env, fallback theo platform
    : pb = PocketBase(_resolvePocketBaseUrl()) {
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

  String _formatPbError(Object error) {
    if (error is ClientException) {
      final status = error.statusCode;
      final message = (error.response['message'] ?? '').toString();
      final data = error.response['data'];

      if (message.isNotEmpty && data != null) {
        return 'PocketBase $status: $message | data: $data';
      }
      if (message.isNotEmpty) {
        return 'PocketBase $status: $message';
      }
      return 'PocketBase $status: $error';
    }
    return error.toString();
  }

  Future<String> _diagnoseNotFoundOnUpdate({
    required String collection,
    required String recordId,
  }) async {
    // PocketBase often returns 404 both when the record truly doesn't exist
    // and when the current user doesn't have access due to collection rules.
    // Try a read to differentiate (best-effort).
    try {
      await pb.collection(collection).getOne(recordId);
      return 'Record exists but update is blocked by PocketBase rules (read ok, update denied).';
    } on ClientException catch (e) {
      if (e.statusCode == 404) {
        return 'Record not found (or read access is also blocked by PocketBase rules).';
      }
      return 'Unexpected error while diagnosing 404: ${_formatPbError(e)}';
    } catch (e) {
      return 'Unexpected error while diagnosing 404: $e';
    }
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
      throw Exception(
        'Failed to load tables (tables:list): ${_formatPbError(e)}',
      );
    }
  }

  Future<void> updateTableStatus(String tableId, String newStatus) async {
    try {
      await pb
          .collection('tables')
          .update(tableId, body: {'status': newStatus});
    } catch (e) {
      print('Error updating table status: $e');
      throw Exception(
        'Failed to update table (tables:update $tableId): ${_formatPbError(e)}',
      );
    }
  }

  Future<TableModel> createTable({
    required String name,
    String status = 'empty',
  }) async {
    try {
      final record = await pb
          .collection('tables')
          .create(body: {'name': name, 'status': status});
      return TableModel.fromRecord(record);
    } catch (e) {
      print('Error creating table: $e');
      throw Exception(
        'Failed to create table (tables:create): ${_formatPbError(e)}',
      );
    }
  }

  Future<void> updateTable({
    required String id,
    required String name,
    required String status,
  }) async {
    try {
      await pb
          .collection('tables')
          .update(id, body: {'name': name, 'status': status});
    } catch (e) {
      print('Error updating table: $e');
      throw Exception(
        'Failed to update table (tables:update $id): ${_formatPbError(e)}',
      );
    }
  }

  Future<void> deleteTable(String id) async {
    try {
      await pb.collection('tables').delete(id);
    } catch (e) {
      print('Error deleting table: $e');
      throw Exception(
        'Failed to delete table (tables:delete $id): ${_formatPbError(e)}',
      );
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
      throw Exception(
        'Failed to create order record (orders:create): ${_formatPbError(e)}',
      );
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
      throw Exception(
        'Failed to create order item record (order_items:create): ${_formatPbError(e)}',
      );
    }
  }

  Future<void> updateOrderItemRecord({
    required String orderItemId,
    required int quantity,
    String? notes,
  }) async {
    try {
      await pb
          .collection('order_items')
          .update(orderItemId, body: {'quantity': quantity, 'notes': notes});
    } catch (e) {
      throw Exception(
        'Failed to update order item (order_items:update $orderItemId): ${_formatPbError(e)}',
      );
    }
  }

  Future<void> deleteOrderItemRecord(String orderItemId) async {
    try {
      await pb.collection('order_items').delete(orderItemId);
    } catch (e) {
      throw Exception(
        'Failed to delete order item (order_items:delete $orderItemId): ${_formatPbError(e)}',
      );
    }
  }

  // --- CÁC HÀM CHO LOGIC BÀN ĐÃ CÓ KHÁCH ---

  Future<OrderModel?> getPendingOrderForTable(String tableId) async {
    final safeTableId = tableId.trim();
    if (safeTableId.isEmpty) return null;
    try {
      // IMPORTANT: There can be many historical orders with the same table.
      // Always pick the most recent one to represent the current (pending) order.
      final result = await pb
          .collection('orders')
          .getList(
            page: 1,
            perPage: 1,
            filter: 'table = "$safeTableId"',
            sort: '-created',
          );

      if (result.items.isEmpty) return null;
      return OrderModel.fromRecord(result.items.first);
    } on ClientException catch (e) {
      if (e.statusCode == 404) {
        return null;
      }
      throw Exception(
        'Error fetching pending order (orders:list table=$safeTableId): ${_formatPbError(e)}',
      );
    } catch (e) {
      throw Exception(
        'Error fetching pending order (orders:list table=$safeTableId): ${_formatPbError(e)}',
      );
    }
  }

  Future<List<OrderItemView>> getOrderItemsWithDetails(String orderId) async {
    try {
      final records = await pb
          .collection('order_items')
          .getFullList(filter: 'order = "$orderId"', expand: 'menu_item');

      final List<OrderItemView> result = [];

      for (final record in records) {
        final notes = record.getStringValue('notes');

        // PocketBase expand for a single-relation is usually a RecordModel.
        // Some SDK versions may return a List<RecordModel>. Handle both.
        RecordModel? menuItemRecord = _extractExpandedRecord(
          record,
          'expand.menu_item',
        );

        if (menuItemRecord == null) {
          // Fallback: read relation id and fetch the menu item directly.
          final menuItemId = _extractRelationId(record, 'menu_item');
          if (_looksLikePocketBaseId(menuItemId)) {
            try {
              menuItemRecord = await pb
                  .collection('menu_items')
                  .getOne(menuItemId);
            } catch (_) {
              // ignore -> will fall back to deleted placeholder
            }
          }
        }

        if (menuItemRecord == null) {
          final fakeRecord = RecordModel({
            'id': _extractRelationId(record, 'menu_item'),
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
          result.add(
            OrderItemView(
              id: record.id,
              quantity: record.getIntValue('quantity'),
              price: record.getDoubleValue('price'),
              menuItem: deletedMenuItem,
              notes: notes,
            ),
          );
          continue;
        }

        final menuItem = MenuItemModel.fromRecord(menuItemRecord, pb);
        result.add(
          OrderItemView(
            id: record.id,
            quantity: record.getIntValue('quantity'),
            price: record.getDoubleValue('price'),
            menuItem: menuItem,
            notes: notes,
          ),
        );
      }

      return result;
    } catch (e) {
      print('Error fetching order items: $e');
      throw Exception(
        'Failed to load order items (order_items:list order=$orderId): ${_formatPbError(e)}',
      );
    }
  }

  // --- SỬA HÀM NÀY (TẠM THỜI VÔ HIỆU HÓA TRỪ KHO) ---
  Future<void> checkoutOrder(String orderId, String tableId) async {
    final safeOrderId = orderId.trim();
    final safeTableId = tableId.trim();
    if (safeOrderId.isEmpty) {
      throw Exception('Failed to process checkout: orderId is empty');
    }
    if (safeTableId.isEmpty) {
      throw Exception('Failed to process checkout: tableId is empty');
    }

    try {
      // 2. Trừ kho nguyên liệu SAU khi thanh toán.
      // Nếu trừ kho lỗi (thiếu nguyên liệu), throw để không giải phóng bàn.
      final itemsInOrder = await getOrderItemsWithDetails(safeOrderId);
      await inventory.deductStockForOrder(itemsInOrder);

      // 3. Chuyển bàn về "trống" (chỉ sau khi trừ kho thành công)
      try {
        await pb
            .collection('tables')
            .update(safeTableId, body: {'status': 'empty'});
      } on ClientException catch (e) {
        if (e.statusCode == 404) {
          final diag = await _diagnoseNotFoundOnUpdate(
            collection: 'tables',
            recordId: safeTableId,
          );
          throw Exception(
            'Failed to process checkout (tables:update $safeTableId): ${_formatPbError(e)}. $diag',
          );
        }
        throw Exception(
          'Failed to process checkout (tables:update $safeTableId): ${_formatPbError(e)}',
        );
      }
    } catch (e) {
      print('Error during checkout: $e');
      throw Exception(
        'Failed to process checkout (tables:update + inventory:deduct): ${_formatPbError(e)}',
      );
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
      throw Exception(
        'Failed to update order total price (orders:update $orderId): ${_formatPbError(e)}',
      );
    }
  }

  String _escapeFilterValue(String value) {
    return value.replaceAll("'", "''");
  }

  String _formatPbUtc(DateTime dateTime) {
    // PocketBase commonly uses the space-separated RFC3339 format in filters.
    // Example: 2026-03-29 16:59:59.000Z
    return dateTime.toUtc().toIso8601String().replaceFirst('T', ' ');
  }

  bool _looksLikePocketBaseId(String value) {
    // PocketBase default record id is typically a 15-char base62-like string.
    return RegExp(r'^[a-z0-9]{15}$', caseSensitive: false).hasMatch(value);
  }

  String _extractRelationId(RecordModel record, String field) {
    final direct = record.getStringValue(field).trim();
    if (direct.isNotEmpty) return direct;

    // Some PocketBase SDK versions may deserialize relation fields differently.
    // Try a dynamic read to cover String / List / Map shapes.
    try {
      final any = record.get<dynamic>(field);
      if (any is String && any.trim().isNotEmpty) return any.trim();
      if (any is List && any.isNotEmpty) return any.first.toString().trim();
      if (any is Map && any['id'] != null) return any['id'].toString().trim();
    } catch (_) {
      // continue
    }

    try {
      final list = record.get<List<String>?>(field);
      if (list != null && list.isNotEmpty) return list.first.trim();
    } catch (_) {
      // continue
    }

    try {
      final list = record.get<List<dynamic>?>(field);
      if (list != null && list.isNotEmpty) return list.first.toString().trim();
    } catch (_) {
      // ignore
    }

    // Some unexpected payloads may contain a map instead of an id.
    try {
      final map = record.get<Map<String, dynamic>?>(field);
      if (map != null) {
        final id = (map['id'] ?? map['recordId'] ?? '').toString().trim();
        if (id.isNotEmpty) return id;
        final name = (map['name'] ?? '').toString().trim();
        if (name.isNotEmpty) return name;
      }
    } catch (_) {
      // ignore
    }

    return '';
  }

  RecordModel? _extractExpandedRecord(RecordModel record, String keyPath) {
    // PocketBase expand values can vary by SDK/version. Prefer the recommended
    // dot-notation access via get<T>("expand.xxx").
    try {
      final expanded = record.get<RecordModel?>(keyPath);
      if (expanded != null) return expanded;
    } catch (_) {
      // continue
    }

    try {
      final expandedList = record.get<List<RecordModel>?>(keyPath);
      if (expandedList != null && expandedList.isNotEmpty) {
        return expandedList.first;
      }
    } catch (_) {
      // continue
    }

    // Some SDKs may deserialize expanded records as raw maps.
    try {
      final expandedMap = record.get<Map<String, dynamic>?>(keyPath);
      if (expandedMap != null) return RecordModel(expandedMap);
    } catch (_) {
      // continue
    }

    try {
      final expandedDynamicList = record.get<List<dynamic>?>(keyPath);
      final first =
          (expandedDynamicList != null && expandedDynamicList.isNotEmpty)
          ? expandedDynamicList.first
          : null;
      if (first is RecordModel) return first;
      if (first is Map<String, dynamic>) return RecordModel(first);
    } catch (_) {
      // continue
    }

    // Last resort: use deprecated expand map if available.
    // In pocketbase ^0.23.0 this is typically Map<String, List<RecordModel>>.
    try {
      final key = keyPath.split('.').last;
      final dynamic expandAny = (record as dynamic).expand;
      final dynamic expandedValue = (expandAny is Map) ? expandAny[key] : null;
      if (expandedValue == null) return null;

      if (expandedValue is List) {
        if (expandedValue.isEmpty) return null;
        final first = expandedValue.first;
        if (first is RecordModel) return first;
        if (first is Map<String, dynamic>) return RecordModel(first);
        return null;
      }

      if (expandedValue is RecordModel) return expandedValue;
      if (expandedValue is Map<String, dynamic>) {
        return RecordModel(expandedValue);
      }
    } catch (_) {
      // ignore
    }

    return null;
  }

  Future<List<OrderViewModel>> getCompletedOrders({
    DateTime? selectedDate,
    DateTime? startDateTimeLocal,
    DateTime? endDateTimeLocal,
    String? searchTerm,
  }) async {
    try {
      final now = DateTime.now();
      DateTime computedStartLocal;
      DateTime computedEndLocal;

      if (startDateTimeLocal != null && endDateTimeLocal != null) {
        computedStartLocal = startDateTimeLocal;
        computedEndLocal = endDateTimeLocal;
      } else if (selectedDate != null) {
        computedStartLocal = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
        );
        computedEndLocal = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          23,
          59,
          59,
        );
      } else {
        final thirtyDaysAgo = now.subtract(const Duration(days: 30));
        computedStartLocal = DateTime(
          thirtyDaysAgo.year,
          thirtyDaysAgo.month,
          thirtyDaysAgo.day,
        );
        computedEndLocal = DateTime(now.year, now.month, now.day, 23, 59, 59);
      }

      // Use end-exclusive range to avoid edge/millisecond issues.
      final endExclusiveLocal = computedEndLocal.add(
        const Duration(seconds: 1),
      );

      final startFilter = _formatPbUtc(computedStartLocal);
      final endExclusiveFilter = _formatPbUtc(endExclusiveLocal);

      List<String> filters = [
        'created >= "$startFilter"',
        'created < "$endExclusiveFilter"',
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
            expand: 'created_by,table',
          );

      print('Found ${records.length} paid orders');

      if (kDebugMode) {
        final previewCount = records.length < 5 ? records.length : 5;
        for (var i = 0; i < previewCount; i++) {
          final r = records[i];
          final raw = r.getStringValue('table').trim();
          final rel = _extractRelationId(r, 'table');
          debugPrint(
            '[getCompletedOrders] order=${r.id.substring(0, 8)} tableRaw="$raw" tableRel="$rel"',
          );
        }
      }

      final Map<String, RecordModel?> tableCache = {};

      final mapped = records.map((record) {
        final tableRecord = _extractExpandedRecord(record, 'expand.table');
        final creatorRecord = _extractExpandedRecord(
          record,
          'expand.created_by',
        );
        return (record, tableRecord, creatorRecord);
      }).toList();

      // Resolve missing table records (if expand.table wasn't available)
      for (var i = 0; i < mapped.length; i++) {
        final (record, tableRecord, creatorRecord) = mapped[i];
        if (tableRecord != null) {
          final tableId = _extractRelationId(record, 'table');
          if (tableId.isNotEmpty && _looksLikePocketBaseId(tableId)) {
            tableCache[tableId] = tableRecord;
          }
          continue;
        }
        final tableId = _extractRelationId(record, 'table');
        if (tableId.isEmpty || !_looksLikePocketBaseId(tableId)) {
          if (kDebugMode) {
            debugPrint(
              '[getCompletedOrders] missing expand.table for order=${record.id.substring(0, 8)}; tableId="$tableId"',
            );
          }
          continue;
        }
        if (tableCache.containsKey(tableId)) continue;
        try {
          tableCache[tableId] = await pb.collection('tables').getOne(tableId);
        } catch (_) {
          tableCache[tableId] = null;
          if (kDebugMode) {
            debugPrint(
              '[getCompletedOrders] failed to fetch table=$tableId for order=${record.id.substring(0, 8)}',
            );
          }
        }
      }

      final orderViews = mapped.map((t) {
        final (record, tableRecord, creatorRecord) = t;
        final tableId = _extractRelationId(record, 'table');
        final resolvedTableRecord = (tableRecord != null)
            ? tableRecord
            : (tableId.isNotEmpty ? tableCache[tableId] : null);
        return OrderViewModel.fromRecord(
          record,
          resolvedTableRecord,
          creatorRecord,
        );
      }).toList();

      // Defensive client-side filtering in local time.
      // Ensures UI doesn't show adjacent days if backend filtering is loose.
      final filtered = orderViews
          .where(
            (o) =>
                !o.created.isBefore(computedStartLocal) &&
                o.created.isBefore(endExclusiveLocal),
          )
          .toList();

      return filtered;
    } catch (e) {
      print('Error fetching completed orders: $e');
      throw Exception(
        'Failed to load completed orders (orders:list): ${_formatPbError(e)}',
      );
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
