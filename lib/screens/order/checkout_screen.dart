import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:myshop/models/order.dart';
import 'package:myshop/models/order_item_view.dart';
import 'package:myshop/utils/currency_formatter.dart';
import 'package:qr_flutter/qr_flutter.dart';

class CheckoutScreen extends StatelessWidget {
  final OrderModel order;
  final List<OrderItemView> items;
  final double totalPrice;
  final String restaurantAddress =
      "125/2 Hòa Hưng, Quận 10, Thành phố Hồ Chí Minh";
  final String vietqrAccount = "1026325913";
  final String vietqrBankBin = "970436"; // BIN của Vietcombank

  const CheckoutScreen({
    super.key,
    required this.order,
    required this.items,
    required this.totalPrice,
  });

  // Tạo chuỗi VietQR
  String get qrData {
    return 'vietqr://transfer/$vietqrBankBin/$vietqrAccount?amount=${totalPrice.toInt()}&addInfo=HD${order.id.substring(0, 8)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hóa Đơn Thanh Toán'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                'CÀ PHÊ CT484', // Tên quán (Bạn có thể đổi)
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Center(child: Text(restaurantAddress, textAlign: TextAlign.center)),
            const Divider(height: 24),
            _buildInfoRow('Mã HĐ:', order.id.substring(0, 15)),
            _buildInfoRow(
              'Ngày giờ:',
              DateFormat('HH:mm dd/MM/yyyy').format(order.created),
            ),
            const Divider(height: 24),

            // Danh sách món ăn
            _buildItemsList(),

            const Divider(height: 24),
            // Tổng tiền
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TỔNG TIỀN',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  formatCurrency(totalPrice),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Mã QR
            Center(
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 200.0,
              ),
            ),
            Center(
              child: Text(
                'STK: $vietqrAccount (Vietcombank)',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            const Center(child: Text('Quét VietQR để thanh toán')),
            const SizedBox(height: 100), // Khoảng đệm cho thanh bottom bar
          ],
        ),
      ),
      // Các nút bấm ở dưới cùng
      bottomNavigationBar: BottomAppBar(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Thoát'),
                onPressed: () {
                  Navigator.of(
                    context,
                  ).pop(false); // Trả về false (chưa thanh toán)
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Xác nhận Đã Thanh toán'),
                onPressed: () {
                  Navigator.of(
                    context,
                  ).pop(true); // Trả về true (ĐÃ thanh toán)
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    return ListView.builder(
      itemCount: items.length,
      shrinkWrap: true, // Quan trọng khi lồng ListView
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final item = items[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  item.menuItem.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '${item.quantity} x ${formatCurrency(item.price)}',
                  textAlign: TextAlign.right,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  formatCurrency(item.subtotal),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
