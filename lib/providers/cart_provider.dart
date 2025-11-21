import 'package:flutter/foundation.dart';
import '../models/cart_item.dart';
import '../models/menu_item.dart';

class CartProvider extends ChangeNotifier {
  final Map<String, CartItem> _items = {};

  Map<String, CartItem> get items => {..._items};

  int get itemCount =>
      _items.values.fold(0, (sum, item) => sum + item.quantity);

  double get totalAmount =>
      _items.values.fold(0.0, (sum, item) => sum + item.subtotal);

  bool get isEmpty => _items.isEmpty;

  List<CartItem> get cartItems => _items.values.toList();

  void addItem(MenuItemModel menuItem) {
    if (_items.containsKey(menuItem.id)) {
      _items[menuItem.id]!.quantity++;
    } else {
      _items[menuItem.id] = CartItem(item: menuItem, quantity: 1);
    }
    notifyListeners();
  }

  void removeItem(String menuItemId) {
    _items.remove(menuItemId);
    notifyListeners();
  }

  void updateQuantity(String menuItemId, int quantity) {
    if (quantity <= 0) {
      removeItem(menuItemId);
    } else if (_items.containsKey(menuItemId)) {
      _items[menuItemId]!.quantity = quantity;
      notifyListeners();
    }
  }

  void updateNotes(String menuItemId, String notes) {
    if (_items.containsKey(menuItemId)) {
      _items[menuItemId]!.notes = notes;
      notifyListeners();
    }
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  CartItem? getItem(String menuItemId) {
    return _items[menuItemId];
  }

  int getQuantity(String menuItemId) {
    return _items[menuItemId]?.quantity ?? 0;
  }
}
