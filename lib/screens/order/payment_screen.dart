import 'package:flutter/material.dart';
import 'package:myshop/models/cart_item.dart';
import 'package:myshop/utils/currency_formatter.dart';
import 'package:myshop/services/pocketbase_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class PaymentScreen extends StatefulWidget {
  final List<CartItem> cartItems;
  final double totalPrice;

  const PaymentScreen({
    super.key,
    required this.cartItems,
    required this.totalPrice,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final PocketBaseService pbService = PocketBaseService.instance;
  bool _isProcessing = false;
  String? _orderId;
  DateTime? _orderDateTime;

  @override
  void initState() {
    super.initState();
    _generateOrderInfo();
  }

  void _generateOrderInfo() {
    _orderDateTime = DateTime.now();
    _orderId = 'HD${_orderDateTime!.millisecondsSinceEpoch}';
  }

  Future<void> _confirmPayment() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // Tạo order record
      final orderId = await pbService.createOrderRecord(widget.totalPrice);

      // Tạo order items
      for (final cartItem in widget.cartItems) {
        await pbService.createOrderItemRecord(
          orderId: orderId,
          menuItemId: cartItem.item.id,
          quantity: cartItem.quantity,
          price: cartItem.item.price,
          notes: cartItem.notes,
        );
      }

      if (!mounted) return;

      // Hiển thị dialog thành công và in hóa đơn
      await _showSuccessDialog();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi xử lý thanh toán: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _showSuccessDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 30),
              SizedBox(width: 8),
              Text('Thanh toán thành công'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Hóa đơn đã được tạo thành công!'),
              const SizedBox(height: 16),
              const Text('Hóa đơn sẽ được in ra...'),
              const SizedBox(height: 16),
              // Hiển thị thông tin hóa đơn ngắn gọn
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text('Mã hóa đơn: $_orderId'),
                    Text(
                      'Thời gian: ${DateFormat('dd/MM/yyyy HH:mm').format(_orderDateTime!)}',
                    ),
                    Text('Tổng tiền: ${formatCurrency(widget.totalPrice)}'),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Đóng dialog
                Navigator.of(
                  context,
                ).popUntil((route) => route.isFirst); // Về trang chủ
              },
              child: const Text('Hoàn tất'),
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
        title: const Text('Thanh toán hóa đơn'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isProcessing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Đang xử lý thanh toán...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thông tin quán
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            '04siCafe',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Địa chỉ: Ninh Kiều, Cần Thơ',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Mã hóa đơn: $_orderId',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Ngày giờ: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(_orderDateTime!)}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Danh sách món đặt
                  const Text(
                    'Danh sách món đặt:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          ...widget.cartItems.map((cartItem) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          cartItem.item.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          '${formatCurrency(cartItem.item.price)} x ${cartItem.quantity}',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (cartItem.notes != null &&
                                            cartItem.notes!.isNotEmpty)
                                          Text(
                                            'Ghi chú: ${cartItem.notes}',
                                            style: const TextStyle(
                                              color: Colors.deepPurple,
                                              fontSize: 12,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    formatCurrency(cartItem.subtotal),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),

                          const Divider(thickness: 1),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'TỔNG CỘNG:',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                formatCurrency(widget.totalPrice),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Nút xác nhận thanh toán
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _confirmPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Xác nhận đã thanh toán',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
