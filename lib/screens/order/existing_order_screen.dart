// [DÁN TOÀN BỘ CODE NÀY VÀO lib/screens/order/existing_order_screen.dart]

import 'package:flutter/material.dart';
import 'package:myshop/models/table.dart';
import 'package:myshop/models/order.dart';
import 'package:myshop/models/order_item_view.dart';
import 'package:myshop/services/pocketbase_service.dart';
import 'package:myshop/utils/currency_formatter.dart';
import 'order_detail_screen.dart';
import 'checkout_screen.dart';

class ExistingOrderScreen extends StatefulWidget {
  final TableModel table;

  const ExistingOrderScreen({super.key, required this.table});

  @override
  State<ExistingOrderScreen> createState() => _ExistingOrderScreenState();
}

class _ExistingOrderScreenState extends State<ExistingOrderScreen> {
  final pbService = PocketBaseService.instance;

  late Future<bool> _orderDataFuture;
  OrderModel? _order;
  List<OrderItemView> _items = [];
  double _totalPrice = 0.0;
  bool _isProcessingCheckout = false;

  @override
  void initState() {
    super.initState();
    _orderDataFuture = _loadOrderData();
  }

  Future<bool> _loadOrderData() async {
    setState(() {
      _order = null;
      _items = [];
      _totalPrice = 0.0;
    });
    try {
      final order = await pbService.getPendingOrderForTable(widget.table.id);
      if (order == null) {
        throw Exception('Không tìm thấy hóa đơn "pending" nào cho bàn này.');
      }
      final items = await pbService.getOrderItemsWithDetails(order.id);
      double total = 0.0;
      for (var item in items) {
        total += item.subtotal;
      }
      if (mounted) {
        setState(() {
          _order = order;
          _items = items;
          _totalPrice = total;
        });
      }
      return true;
    } catch (e) {
      print('Lỗi khi tải _loadOrderData: $e');
      rethrow;
    }
  }

  void _onOrderMore() async {
    if (_order == null) return;

    final bool? didUpdate = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) =>
            OrderDetailScreen(table: widget.table, existingOrder: _order),
      ),
    );

    if (didUpdate == true && mounted) {
      setState(() {
        _orderDataFuture = _loadOrderData();
      });
    }
  }

  void _onCheckout() async {
    if (_order == null) return;

    final bool? didConfirmPayment = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => CheckoutScreen(
          order: _order!,
          items: _items,
          totalPrice: _totalPrice,
          tableName: widget.table.name,
        ),
      ),
    );

    if (didConfirmPayment != true) return;

    setState(() {
      _isProcessingCheckout = true;
    });

    try {
      await pbService.checkoutOrder(_order!.id, widget.table.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã thanh toán thành công cho ${widget.table.name}!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi thanh toán: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingCheckout = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chi tiết ${widget.table.name}'),
        backgroundColor: Colors.red.shade400,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<bool>(
        future: _orderDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text('Đang tải thông tin hóa đơn...'),
                ],
              ),
            );
          }

          if (snapshot.hasError || _order == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 40,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Lỗi tải dữ liệu hóa đơn: ${snapshot.error ?? "Không tìm thấy hóa đơn"}',
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => setState(() {
                        _orderDataFuture = _loadOrderData();
                      }),
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Trạng thái Thành công (Hiển thị dữ liệu)
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Các món đã gọi (${_items.length})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      formatCurrency(_totalPrice),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // --- SỬA PHẦN NÀY (HIỂN THỊ GHI CHÚ) ---
              Expanded(
                child: _items.isEmpty
                    ? const Center(child: Text("Chưa có món nào được gọi."))
                    : ListView.builder(
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final bool hasNote =
                              item.notes != null && item.notes!.isNotEmpty;

                          return ListTile(
                            leading:
                                (item.menuItem.imageUrl != null &&
                                    item.menuItem.imageUrl!.isNotEmpty)
                                ? Image.network(
                                    item.menuItem.imageUrl!,
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.broken_image,
                                      size: 50,
                                      color: Colors.grey,
                                    ),
                                  )
                                : const SizedBox(
                                    width: 50,
                                    height: 50,
                                    child: Icon(
                                      Icons.fastfood,
                                      color: Colors.grey,
                                    ),
                                  ),
                            title: Text(
                              item.menuItem.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${item.quantity} x ${formatCurrency(item.price)}'
                              // Hiển thị ghi chú nếu có
                              '${hasNote ? '\nGhi chú: ${item.notes}' : ''}',
                              style: TextStyle(
                                color: hasNote ? Colors.deepPurple : null,
                              ),
                            ),
                            // Tự động dãn ra
                            isThreeLine: hasNote,
                            trailing: Text(
                              formatCurrency(item.subtotal),
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                              ),
                            ),
                          );
                        },
                      ),
              ),

              if (_isProcessingCheckout)
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                )
              else
                _buildActionButtons(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.edit_note), // <-- Đổi icon
              label: const Text('Gọi thêm/Sửa'), // <-- Đổi text
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              onPressed: _onOrderMore,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.payment),
              label: const Text('Thanh Toán'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              onPressed: _onCheckout,
            ),
          ),
        ],
      ),
    );
  }
}
