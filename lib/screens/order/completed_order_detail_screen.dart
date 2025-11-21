import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:myshop/services/pocketbase_service.dart';
import 'package:myshop/utils/currency_formatter.dart';
import 'package:myshop/models/order_item_view.dart';
// Import cho OrderViewModel
import 'package:myshop/models/order_view.dart';

class CompletedOrderDetailScreen extends StatefulWidget {
  final OrderViewModel orderView;

  const CompletedOrderDetailScreen({super.key, required this.orderView});

  @override
  State<CompletedOrderDetailScreen> createState() =>
      _CompletedOrderDetailScreenState();
}

class _CompletedOrderDetailScreenState
    extends State<CompletedOrderDetailScreen> {
  late Future<List<OrderItemView>> _itemsFuture;
  final pbService = PocketBaseService.instance;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  void _loadItems() {
    setState(() {
      _itemsFuture = pbService.getOrderItemsWithDetails(widget.orderView.id);
    });
  }

  // Widget để hiển thị thông tin chung
  // Widget để hiển thị thông tin chung
  Widget _buildOrderInfo(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- PHẦN ĐÃ SỬA ---
            Text(
              'Hóa đơn ${widget.orderView.tableName}', // Chỉ hiển thị tên bàn
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4), // Thêm khoảng cách nhỏ
            Text(
              'ID: ${widget.orderView.id}', // Hiển thị ID đầy đủ ở dòng riêng
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade700, // Màu xám cho ID
              ),
            ),
            const Divider(),
            _buildInfoRow(
              'Thời gian:',
              DateFormat(
                'HH:mm:ss - dd/MM/yyyy',
              ).format(widget.orderView.created),
            ),
            _buildInfoRow('Người tạo:', widget.orderView.createdByUsername),
            const SizedBox(height: 8),
            _buildInfoRow(
              'Tổng tiền:',
              formatCurrency(widget.orderView.totalPrice),
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    Color? color,
    bool isTotal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 18 : 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              fontSize: isTotal ? 18 : 14,
              color: color ?? (isTotal ? Colors.red.shade700 : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  // Widget hiển thị danh sách món ăn
  Widget _buildItemList() {
    return FutureBuilder<List<OrderItemView>>(
      future: _itemsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Lỗi tải món ăn: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return const Center(child: Text('Hóa đơn không có món ăn nào.'));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                // Đã fix lỗi getter 'display' trong file order.dart trước đó
                'Danh sách món ăn:',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];

                // --- LOGIC HIỂN THỊ HÌNH ẢNH ĐƯỢC THÊM VÀO ---
                final imageUrl = item.menuItem.imageUrl;

                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Container(
                      width: 50,
                      height: 50,
                      color: Colors.grey.shade200,
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              // Xử lý lỗi khi tải ảnh thất bại
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(
                                    Icons.broken_image,
                                    size: 30,
                                    color: Colors.red,
                                  ),
                            )
                          : const Icon(
                              Icons.restaurant_menu,
                              size: 30,
                              color: Colors.blueGrey,
                            ),
                    ),
                  ),
                  // --- KẾT THÚC LOGIC HIỂN THỊ HÌNH ẢNH ---
                  title: Text(item.menuItem.name),
                  subtitle: Text(
                    '${formatCurrency(item.price)}/${item.menuItem.unit} x ${item.quantity}',
                  ),
                  trailing: Text(
                    formatCurrency(item.price * item.quantity),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi Tiết Hóa Đơn'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOrderInfo(context),
            _buildItemList(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
