// lib/screens/order/completed_orders_screen.dart (ĐÃ NÂNG CẤP)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:myshop/services/pocketbase_service.dart';
import 'package:myshop/utils/currency_formatter.dart';
import 'package:myshop/screens/order/completed_order_detail_screen.dart';
import 'package:myshop/models/order_view.dart';

class CompletedOrdersScreen extends StatefulWidget {
  const CompletedOrdersScreen({super.key});

  @override
  State<CompletedOrdersScreen> createState() => _CompletedOrdersScreenState();
}

class _CompletedOrdersScreenState extends State<CompletedOrdersScreen> {
  final pbService = PocketBaseService.instance;
  final TextEditingController _searchController = TextEditingController();

  // Lọc theo thời gian
  DateFilterType _dateFilterType = DateFilterType.last30Days;
  DateTime? _selectedDay;
  int? _selectedMonth;
  int? _selectedYear;

  String _searchQuery = ""; // Từ khóa tìm kiếm (ID)

  // Biến Future để tải lại
  late Future<List<OrderViewModel>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    // Gán hàm _loadOrders cho future
    _ordersFuture = _loadOrders();
    // Lắng nghe thay đổi của thanh tìm kiếm
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  // Hàm gọi service với các tham số hiện tại
  Future<List<OrderViewModel>> _loadOrders() {
    final dateRange = _computeLocalDateRange();
    return pbService.getCompletedOrders(
      startDateTimeLocal: dateRange?.start,
      endDateTimeLocal: dateRange?.end,
      searchTerm: _searchQuery,
    );
  }

  // Hàm refresh (gọi lại future)
  void _refreshData() {
    setState(() {
      _ordersFuture = _loadOrders();
    });
  }

  // Xử lý khi nhập tìm kiếm
  void _onSearchChanged() {
    if (_searchQuery != _searchController.text) {
      setState(() {
        _searchQuery = _searchController.text;
        _ordersFuture = _loadOrders(); // Tải lại dữ liệu với từ khóa mới
      });
    }
  }

  // Xử lý khi bấm vào chi tiết
  void _navigateToDetail(OrderViewModel order) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => CompletedOrderDetailScreen(orderView: order),
          ),
        )
        .then((_) {
          // Khi quay lại từ màn hình chi tiết, tự động refresh
          _refreshData();
        });
  }

  // Hàm lấy tiêu đề động
  String _getTitle() {
    final now = DateTime.now();
    switch (_dateFilterType) {
      case DateFilterType.last30Days:
        return 'Tất cả hóa đơn';
      case DateFilterType.day:
        final day = _selectedDay ?? DateTime(now.year, now.month, now.day);
        return DateFormat('dd/MM/yyyy').format(day);
      case DateFilterType.month:
        final month = _selectedMonth ?? now.month;
        final year = _selectedYear ?? now.year;
        return 'Tháng ${month.toString().padLeft(2, '0')}/$year';
      case DateFilterType.year:
        final year = _selectedYear ?? now.year;
        return 'Năm $year';
    }
  }

  DateTimeRange? _computeLocalDateRange() {
    final now = DateTime.now();
    switch (_dateFilterType) {
      case DateFilterType.last30Days:
        return null;
      case DateFilterType.day:
        final day = _selectedDay ?? DateTime(now.year, now.month, now.day);
        final start = DateTime(day.year, day.month, day.day);
        final end = DateTime(day.year, day.month, day.day, 23, 59, 59);
        return DateTimeRange(start: start, end: end);
      case DateFilterType.month:
        final year = _selectedYear ?? now.year;
        final month = _selectedMonth ?? now.month;
        final start = DateTime(year, month, 1);
        final end = DateTime(year, month + 1, 0, 23, 59, 59);
        return DateTimeRange(start: start, end: end);
      case DateFilterType.year:
        final year = _selectedYear ?? now.year;
        final start = DateTime(year, 1, 1);
        final end = DateTime(year, 12, 31, 23, 59, 59);
        return DateTimeRange(start: start, end: end);
    }
  }

  String _filterTypeLabel(DateFilterType type) {
    switch (type) {
      case DateFilterType.last30Days:
        return '30 ngày';
      case DateFilterType.day:
        return 'Ngày';
      case DateFilterType.month:
        return 'Tháng';
      case DateFilterType.year:
        return 'Năm';
    }
  }

  Future<void> _openFilterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Lọc hóa đơn'),
                subtitle: Text(
                  'Đang chọn: ${_filterTypeLabel(_dateFilterType)}',
                ),
              ),
              const Divider(height: 1),
              ...DateFilterType.values.map(
                (type) => ListTile(
                  leading: Icon(
                    type == DateFilterType.last30Days
                        ? Icons.history
                        : Icons.event,
                  ),
                  title: Text(_filterTypeLabel(type)),
                  trailing: type == _dateFilterType
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _applyFilter(type);
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _applyFilter(DateFilterType type) async {
    final now = DateTime.now();

    if (type == DateFilterType.last30Days) {
      setState(() {
        _dateFilterType = DateFilterType.last30Days;
        _selectedDay = null;
        _selectedMonth = null;
        _selectedYear = null;
        _ordersFuture = _loadOrders();
      });
      return;
    }

    if (type == DateFilterType.day) {
      final initial = _selectedDay ?? DateTime(now.year, now.month, now.day);
      final picked = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(2000, 1, 1),
        lastDate: DateTime(now.year + 1, 12, 31),
      );
      if (picked == null) return;
      setState(() {
        _dateFilterType = DateFilterType.day;
        _selectedDay = DateTime(picked.year, picked.month, picked.day);
        _ordersFuture = _loadOrders();
      });
      return;
    }

    if (type == DateFilterType.month) {
      int month = _selectedMonth ?? now.month;
      int year = _selectedYear ?? now.year;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Chọn tháng/năm'),
            content: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: month,
                    decoration: const InputDecoration(labelText: 'Tháng'),
                    items: List.generate(12, (i) => i + 1)
                        .map(
                          (m) => DropdownMenuItem(
                            value: m,
                            child: Text(m.toString().padLeft(2, '0')),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      month = v;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: year,
                    decoration: const InputDecoration(labelText: 'Năm'),
                    items: List.generate(20, (i) => now.year - 10 + i)
                        .map(
                          (y) => DropdownMenuItem(
                            value: y,
                            child: Text(y.toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      year = v;
                    },
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      if (confirmed != true) return;
      setState(() {
        _dateFilterType = DateFilterType.month;
        _selectedMonth = month;
        _selectedYear = year;
        _ordersFuture = _loadOrders();
      });
      return;
    }

    if (type == DateFilterType.year) {
      int year = _selectedYear ?? now.year;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Chọn năm'),
            content: DropdownButtonFormField<int>(
              initialValue: year,
              decoration: const InputDecoration(labelText: 'Năm'),
              items: List.generate(20, (i) => now.year - 10 + i)
                  .map(
                    (y) =>
                        DropdownMenuItem(value: y, child: Text(y.toString())),
                  )
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                year = v;
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      if (confirmed != true) return;
      setState(() {
        _dateFilterType = DateFilterType.year;
        _selectedYear = year;
        _ordersFuture = _loadOrders();
      });
    }
  }

  List<_CompletedOrdersListEntry> _buildGroupedEntries(
    List<OrderViewModel> orders,
  ) {
    final entries = <_CompletedOrdersListEntry>[];
    String? lastGroupKey;

    for (final order in orders) {
      final groupKey = _groupKeyForOrder(order);
      if (lastGroupKey != groupKey) {
        entries.add(_HeaderEntry(title: groupKey));
        lastGroupKey = groupKey;
      }
      entries.add(_OrderEntry(order: order));
    }

    return entries;
  }

  String _groupKeyForOrder(OrderViewModel order) {
    switch (_dateFilterType) {
      case DateFilterType.year:
        return DateFormat('MM/yyyy').format(order.created);
      case DateFilterType.last30Days:
      case DateFilterType.day:
      case DateFilterType.month:
        return DateFormat('dd/MM/yyyy').format(order.created);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle()), // Tiêu đề động
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // --- THANH TÌM KIẾM ---
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Tìm theo ID hóa đơn...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: _openFilterSheet,
                    child: const Icon(Icons.filter_list),
                  ),
                ),
              ],
            ),
          ),
          // --- DANH SÁCH HÓA ĐƠN ---
          Expanded(
            child: FutureBuilder<List<OrderViewModel>>(
              future: _ordersFuture,
              builder: (context, snapshot) {
                // (Trạng thái Loading và Error giữ nguyên)
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Lỗi tải danh sách hóa đơn: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final orders = snapshot.data;
                if (orders == null || orders.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async => _refreshData(),
                    child: ListView(
                      children: [
                        Center(
                          child: Padding(
                            padding: EdgeInsets.only(
                              top: MediaQuery.of(context).size.height * 0.2,
                            ),
                            child: const Text(
                              'Không tìm thấy hóa đơn nào.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final entries = _buildGroupedEntries(orders);

                // Trạng thái Thành công: Hiển thị danh sách
                return RefreshIndicator(
                  onRefresh: () async => _refreshData(),
                  child: ListView.builder(
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];

                      if (entry is _HeaderEntry) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                          child: Text(
                            entry.title,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        );
                      }

                      final order = (entry as _OrderEntry).order;
                      final formattedTime = DateFormat(
                        'HH:mm',
                      ).format(order.created);

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 6.0,
                        ),
                        elevation: 2.0,
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            child: Icon(Icons.check),
                          ),
                          title: Text(
                            '${order.displayTableName} - HĐ: ${order.id.substring(0, 8)}...',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Lúc $formattedTime - ${DateFormat('dd/MM').format(order.created)} bởi ${order.createdByUsername}',
                          ),
                          trailing: Text(
                            formatCurrency(order.totalPrice),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.deepPurple,
                            ),
                          ),
                          onTap: () => _navigateToDetail(order),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

enum DateFilterType { last30Days, day, month, year }

sealed class _CompletedOrdersListEntry {}

class _HeaderEntry extends _CompletedOrdersListEntry {
  final String title;
  _HeaderEntry({required this.title});
}

class _OrderEntry extends _CompletedOrdersListEntry {
  final OrderViewModel order;
  _OrderEntry({required this.order});
}
