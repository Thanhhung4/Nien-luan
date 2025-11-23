import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import 'dart:math';
import '../../models/cart_item.dart';
import '../../services/pocketbase_service.dart';
import '../../providers/cart_provider.dart';

class PaymentScreen extends StatefulWidget {
  final List<CartItem> cartItems;

  const PaymentScreen({Key? key, required this.cartItems}) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final PocketBaseService _pbService = PocketBaseService.instance;
  late String invoiceId;
  late DateTime invoiceDateTime;
  bool isPaymentConfirmed = false;

  @override
  void initState() {
    super.initState();
    invoiceId = _generateInvoiceId();
    invoiceDateTime = DateTime.now();
  }

  String _generateInvoiceId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomNumber = random.nextInt(9999).toString().padLeft(4, '0');
    return 'HD${timestamp.toString().substring(timestamp.toString().length - 6)}$randomNumber';
  }

  double get _totalAmount {
    return widget.cartItems.fold(0, (sum, item) => sum + item.subtotal);
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // Hàm chuyển đổi ký tự tiếng Việt thành ASCII cho PDF
  String _convertToAscii(String text) {
    return text
        .replaceAll('Đ', 'D')
        .replaceAll('đ', 'd')
        .replaceAll('ị', 'i')
        .replaceAll('ỉ', 'i')
        .replaceAll('ề', 'e')
        .replaceAll('ầ', 'a')
        .replaceAll('ơ', 'o')
        .replaceAll('ạ', 'a')
        .replaceAll('₫', 'VND')
        .replaceAll('ả', 'a')
        .replaceAll('ẹ', 'e')
        .replaceAll('ặ', 'a')
        .replaceAll('Ổ', 'O')
        .replaceAll('Ề', 'E')
        .replaceAll('ă', 'a')
        .replaceAll('â', 'a')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ý', 'y')
        .replaceAll('À', 'A')
        .replaceAll('Á', 'A')
        .replaceAll('Â', 'A')
        .replaceAll('Ã', 'A')
        .replaceAll('È', 'E')
        .replaceAll('É', 'E')
        .replaceAll('Ê', 'E')
        .replaceAll('Ì', 'I')
        .replaceAll('Í', 'I')
        .replaceAll('Ò', 'O')
        .replaceAll('Ó', 'O')
        .replaceAll('Ô', 'O')
        .replaceAll('Õ', 'O')
        .replaceAll('Ù', 'U')
        .replaceAll('Ú', 'U')
        .replaceAll('Ý', 'Y')
        .replaceAll('à', 'a')
        .replaceAll('á', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('è', 'e')
        .replaceAll('ì', 'i')
        .replaceAll('ò', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ù', 'u')
        .replaceAll('ũ', 'u')
        .replaceAll('ỳ', 'y');
  }

  void _confirmPayment() async {
    print('=== CONFIRM PAYMENT STARTED ===');
    print('Cart items count: ${widget.cartItems.length}');
    print('Total amount: $_totalAmount');

    setState(() {
      isPaymentConfirmed = true;
    });

    try {
      print('Creating order with total: $_totalAmount');
      // Tạo order mới trong database
      final orderId = await _pbService.createOrderRecord(_totalAmount);
      print('Order created with ID: $orderId');

      // Tạo order items
      for (final cartItem in widget.cartItems) {
        print(
          'Creating order item: ${cartItem.item.name} x${cartItem.quantity}',
        );
        await _pbService.createOrderItemRecord(
          orderId: orderId,
          menuItemId: cartItem.item.id,
          quantity: cartItem.quantity,
          price: cartItem.item.price,
          notes: cartItem.notes,
        );
      }
      print('All order items created');

      // Clear cart thông qua Provider
      if (mounted) {
        context.read<CartProvider>().clear();
        print('Cart cleared via Provider');
      }

      // Hiển thị thông báo thành công (chỉ lưu, chưa in)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hóa đơn đã được lưu thành công!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Không tự động in và chuyển trang nữa
      // Người dùng sẽ chọn "In hóa đơn" hoặc "Không in"
    } catch (e) {
      print('Error in _confirmPayment: $e');
      if (mounted) {
        setState(() {
          isPaymentConfirmed = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi lưu hóa đơn: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _printInvoice() async {
    try {
      // Tạo PDF hóa đơn
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80, // Giấy in nhiệt 80mm
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Header
                pw.Text(
                  _convertToAscii('CA PHE CT484'),
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(_convertToAscii('Dia chi: Ninh Kieu, Can Tho')),
                pw.Text(_convertToAscii('Loai: Tai quan')),
                pw.Divider(),

                // Thông tin hóa đơn
                pw.Text(_convertToAscii('Ma HD: $invoiceId')),
                pw.Text(
                  _convertToAscii('Ngay: ${_formatDateTime(invoiceDateTime)}'),
                ),
                pw.Divider(),

                // Danh sách món
                ...widget.cartItems.map((cartItem) {
                  final item = cartItem.item;
                  return pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            _convertToAscii(
                              '${item.name} x${cartItem.quantity}',
                            ),
                          ),
                        ),
                        pw.Text(
                          _convertToAscii(
                            '${cartItem.subtotal.toStringAsFixed(0)} VND',
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),

                pw.Divider(),

                // Tổng tiền
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      _convertToAscii('TONG TIEN:'),
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    pw.Text(
                      _convertToAscii('${_totalAmount.toStringAsFixed(0)} VND'),
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(height: 10),
                pw.Text(_convertToAscii('Cam on quy khach!')),
                pw.Text(_convertToAscii('Hen gap lai!')),
              ],
            );
          },
        ),
      );

      // In PDF
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );

      // Rung thiết bị để thông báo in xong
      HapticFeedback.heavyImpact();

      print('Invoice printed successfully');
    } catch (e) {
      print('Error printing invoice: $e');
      // Fallback to console print if physical printing fails
      _printToConsole();
    }
  }

  void _printToConsole() {
    // Giả lập việc in hóa đơn ra console (fallback)
    print('=== HOA DON THANH TOAN ===');
    print('The 04siCafe');
    print('Dia chi: Ninh Kieu, Can Tho');
    print('Loai: Tai quan');
    print('Ma hoa don: $invoiceId');
    print('Ngay gio: ${_formatDateTime(invoiceDateTime)}');
    print('----------------------------');

    for (final cartItem in widget.cartItems) {
      final item = cartItem.item;
      print(_convertToAscii('${item.name} x${cartItem.quantity}'));
      print(
        _convertToAscii(
          '  ${item.price.toStringAsFixed(0)} VND x ${cartItem.quantity} = ${cartItem.subtotal.toStringAsFixed(0)} VND',
        ),
      );
    }

    print('----------------------------');
    print(_convertToAscii('TONG TIEN: ${_totalAmount.toStringAsFixed(0)} VND'));
    print('===========================');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thanh toán hóa đơn'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thông tin quán
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '04siCafe',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Địa chỉ: Ninh Kiều, Cần Thơ',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Loại: Tại quán',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Thông tin hóa đơn
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Mã hóa đơn:',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[700],
                          ),
                        ),
                        Text(
                          invoiceId,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Ngày giờ:',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[700],
                          ),
                        ),
                        Text(
                          _formatDateTime(invoiceDateTime),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Danh sách sản phẩm
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chi tiết đơn hàng:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(),

                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: widget.cartItems.length,
                      itemBuilder: (context, index) {
                        final cartItem = widget.cartItems[index];
                        final item = cartItem.item;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${item.price.toStringAsFixed(0)}₫ x ${cartItem.quantity}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${cartItem.subtotal.toStringAsFixed(0)}₫',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const Divider(),

                    // Tổng tiền
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TỔNG TIỀN:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_totalAmount.toStringAsFixed(0)}₫',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
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
              child: ElevatedButton(
                onPressed: isPaymentConfirmed ? null : _confirmPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPaymentConfirmed
                      ? Colors.green
                      : Theme.of(context).primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: isPaymentConfirmed
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Đã thanh toán',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      )
                    : const Text(
                        'Xác nhận đã thanh toán',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),

            if (isPaymentConfirmed) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[300]!),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 48,
                      color: Colors.green[600],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Thanh toán thành công!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bạn có muốn in hóa đơn không?',
                      style: TextStyle(fontSize: 14, color: Colors.green[600]),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _printInvoice();
                              // Delay để cho thấy hiệu ứng in, sau đó chuyển về trang chủ
                              Future.delayed(const Duration(seconds: 2), () {
                                if (mounted) {
                                  Navigator.of(
                                    context,
                                  ).popUntil((route) => route.isFirst);
                                }
                              });
                            },
                            icon: const Icon(Icons.print, color: Colors.white),
                            label: const Text(
                              'In hóa đơn',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // Hiển thị thông báo thành công
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Hóa đơn đã được tạo thành công!',
                                  ),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 2),
                                ),
                              );

                              // Chuyển về trang chủ mà không in
                              Navigator.of(
                                context,
                              ).popUntil((route) => route.isFirst);
                            },
                            icon: const Icon(Icons.home, color: Colors.white),
                            label: const Text(
                              'Không in',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[600],
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
