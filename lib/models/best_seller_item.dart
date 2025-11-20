// [FILE MỚI: lib/models/best_seller_item.dart]

import 'package:myshop/models/menu_item.dart';

class BestSellerItem {
  final MenuItemModel menuItem;
  final int totalQuantity;

  BestSellerItem({required this.menuItem, required this.totalQuantity});
}
