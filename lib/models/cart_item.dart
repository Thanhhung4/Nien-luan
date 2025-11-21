import 'package:myshop/models/menu_item.dart';

class CartItem {
  final MenuItemModel item;
  int quantity;
  String? notes;

  CartItem({
    required this.item,
    this.quantity = 1,
    this.notes,
  });

  double get subtotal => item.price * quantity;
}

