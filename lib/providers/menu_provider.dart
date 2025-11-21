import 'package:flutter/foundation.dart';
import '../models/menu_item.dart';
import '../services/pocketbase_service.dart';

class MenuProvider extends ChangeNotifier {
  final PocketBaseService _pbService = PocketBaseService.instance;
  List<MenuItemModel> _menuItems = [];
  bool _isLoading = false;
  String? _error;

  List<MenuItemModel> get menuItems => _menuItems;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<MenuItemModel> get foodItems => _menuItems
      .where((item) => item.category == MenuItemCategory.food)
      .toList();

  List<MenuItemModel> get drinkItems => _menuItems
      .where((item) => item.category == MenuItemCategory.drink)
      .toList();

  Future<void> loadMenu() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _menuItems = await _pbService.menu.getMenu();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshMenu() async {
    await loadMenu();
  }

  List<MenuItemModel> searchItems(String query) {
    if (query.isEmpty) return _menuItems;
    return _menuItems
        .where((item) => item.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  MenuItemModel? getItemById(String id) {
    try {
      return _menuItems.firstWhere((item) => item.id == id);
    } catch (e) {
      return null;
    }
  }
}
