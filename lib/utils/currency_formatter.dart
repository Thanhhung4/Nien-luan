/// Định dạng một số (double) thành chuỗi tiền tệ VND
///
/// Ví dụ: 50000.0 -> "50.000 VND"
String formatCurrency(double amount) {
  // Chuyển về số nguyên (bỏ .0)
  final String price = amount.toStringAsFixed(0);

  // Sử dụng RegExp để thêm dấu chấm vào mỗi 3 chữ số
  // Ví dụ: "50000" -> "50.000"
  // Ví dụ: "1500000" -> "1.500.000"
  final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
  final String formatted = price.replaceAllMapped(
    reg,
    (Match match) => '${match[1]}.',
  );

  // Thêm " VND"
  return '$formatted VND';
}
