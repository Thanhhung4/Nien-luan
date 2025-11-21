// [DÁN TOÀN BỘ CODE NÀY VÀO lib/services/report_service.dart]

import 'package:pocketbase/pocketbase.dart';
import 'package:myshop/models/order.dart';
import 'package:myshop/models/menu_item.dart';
import 'package:myshop/models/best_seller_item.dart';
import 'package:collection/collection.dart';
import 'package:myshop/models/spoilage_log.dart'; // <-- Import model mới

class ReportService {
  final PocketBase pb;

  ReportService(this.pb);

  /// Lấy danh sách các Order ĐÃ HOÀN THÀNH trong một tháng
  Future<List<OrderModel>> getCompletedOrdersForMonth(
    DateTime selectedMonth,
  ) async {
    final startDate = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final now = DateTime.now();
    DateTime endDate;

    if (selectedMonth.year == now.year && selectedMonth.month == now.month) {
      endDate = now;
    } else {
      endDate = DateTime(
        selectedMonth.year,
        selectedMonth.month + 1,
        0,
        23,
        59,
        59,
      );
    }

    final String startISO = startDate.toUtc().toIso8601String();
    final String endISO = endDate.toUtc().toIso8601String();

    try {
      // Loại bỏ filter status vì đã không sử dụng thuộc tính status nữa
      // Tất cả orders được tạo đều được coi là đã hoàn thành
      final filter = 'created >= "$startISO" && created <= "$endISO"';
      final records = await pb
          .collection('orders')
          .getFullList(filter: filter, sort: 'created');
      return records.map((record) => OrderModel.fromRecord(record)).toList();
    } catch (e) {
      print('ReportService - Error fetching completed orders: $e');
      throw Exception('Lỗi tải dữ liệu báo cáo: $e');
    }
  }

  /// [MỚI] Lấy danh sách thô tất cả món đã bán để tính lợi nhuận theo ngày
  Future<List<RecordModel>> getRawSoldItems(DateTime selectedMonth) async {
    // 1. Lấy danh sách đơn đã thanh toán
    final paidOrders = await getCompletedOrdersForMonth(selectedMonth);
    if (paidOrders.isEmpty) return [];

    // 2. Tạo filter lấy order_items thuộc các đơn này
    final orderIdFilter =
        '(${paidOrders.map((o) => "order.id = '${o.id}'").join(' || ')})';

    try {
      // 3. Lấy dữ liệu và expand menu_item để lấy 'cost'
      // Sắp xếp theo thời gian tạo để vẽ biểu đồ đúng thứ tự
      final items = await pb
          .collection('order_items')
          .getFullList(
            filter: orderIdFilter,
            expand: 'menu_item',
            sort: 'created',
          );
      return items;
    } catch (e) {
      print('ReportService - Error fetching raw items: $e');
      return [];
    }
  }

  /// Lấy Top món bán chạy (Giữ nguyên logic cũ nhưng tái sử dụng hàm trên nếu muốn tối ưu)
  Future<List<BestSellerItem>> getBestSellingItems(
    DateTime selectedMonth,
  ) async {
    // Tận dụng hàm mới để tránh viết lại code filter
    // Lưu ý: Hàm này trả về RecordModel, cần xử lý lại một chút
    List<RecordModel> allItems;
    try {
      allItems = await getRawSoldItems(selectedMonth);
    } catch (e) {
      return [];
    }

    if (allItems.isEmpty) return [];

    final grouped = groupBy(allItems, (RecordModel item) {
      return item.getStringValue('menu_item');
    });

    final List<BestSellerItem> bestSellers = [];

    for (var entry in grouped.entries) {
      int totalQuantity = 0;
      MenuItemModel? menuItem;

      for (var itemRecord in entry.value) {
        totalQuantity += itemRecord.getIntValue('quantity');

        if (menuItem == null && itemRecord.expand.containsKey('menu_item')) {
          final expandedData = itemRecord.get<List<RecordModel>>(
            'expand.menu_item',
          );
          if (expandedData.isNotEmpty) {
            menuItem = MenuItemModel.fromRecord(expandedData.first, pb);
          }
        }
      }

      if (menuItem == null) {
        final firstItem = entry.value.first;
        menuItem = MenuItemModel.fromRecord(
          RecordModel({
            'id': firstItem.getStringValue('menu_item'),
            'collectionId': 'menu_items',
            'created': '',
            'updated': '',
            'name': 'Món đã bị xóa',
            'price': firstItem.getDoubleValue('price'),
            'category': 'food',
            'image': '',
            'in_stock': false,
            'unit': 'N/A',
            'cost': 0.0,
          }),
          pb,
        );
      }

      bestSellers.add(
        BestSellerItem(menuItem: menuItem, totalQuantity: totalQuantity),
      );
    }

    bestSellers.sort((a, b) => b.totalQuantity.compareTo(a.totalQuantity));
    return bestSellers;
  }

  // --- TÍNH TỔNG CHI PHÍ HAO HỤT TRONG THÁNG (DÙNG MODEL) ---
  Future<double> getMonthlySpoilageCost(DateTime selectedMonth) async {
    final startDate = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final endDate = DateTime(
      selectedMonth.year,
      selectedMonth.month + 1,
      0,
      23,
      59,
      59,
    );

    final startISO = startDate.toUtc().toIso8601String();
    final endISO = endDate.toUtc().toIso8601String();

    try {
      // Lấy dữ liệu từ bảng spoilage_logs
      final records = await pb
          .collection('spoilage_logs')
          .getFullList(
            filter: 'created >= "$startISO" && created <= "$endISO"',
          );

      // Chuyển đổi sang Model (Code chuyên nghiệp hơn)
      final logs = records.map((r) => SpoilageLog.fromRecord(r)).toList();

      // Tính tổng tiền mất
      double totalLoss = 0;
      for (var log in logs) {
        totalLoss +=
            log.totalLoss; // Dùng thuộc tính của class, không sợ gõ sai string
      }
      return totalLoss;
    } catch (e) {
      print('Lỗi tính phí hao hụt: $e');
      return 0.0;
    }
  }
}
