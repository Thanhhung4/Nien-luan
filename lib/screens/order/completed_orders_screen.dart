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

  // Biến trạng thái
  DateTime? _selectedDate; // Ngày đang được chọn (null = 30 ngày gần nhất)
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
    return pbService.getCompletedOrders(
      selectedDate: _selectedDate,
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
    if (_selectedDate != null) {
      return '${DateFormat('dd/MM/yyyy').format(_selectedDate!)}';
    }
    return 'Tất cả hóa đơn';
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

                // Trạng thái Thành công: Hiển thị danh sách
                return RefreshIndicator(
                  onRefresh: () async => _refreshData(),
                  child: ListView.builder(
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      // Định dạng thời gian
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
                          // --- SỬA TITLE (Thêm ID) ---
                          title: Text(
                            '${order.tableName} - HĐ: ${order.id.substring(0, 8)}...',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          // --- SỬA SUBTITLE (Thêm ngày) ---
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
