// [DÁN TOÀN BỘ CODE NÀY VÀO lib/screens/manager/manage_menu.dart]

import 'package:flutter/material.dart';
import 'package:myshop/models/menu_item.dart';
import 'package:myshop/services/pocketbase_service.dart';
import 'package:myshop/screens/manager/menu_item_form_screen.dart';
import 'package:myshop/utils/currency_formatter.dart';

class ManageMenuScreen extends StatefulWidget {
  const ManageMenuScreen({super.key});

  @override
  State<ManageMenuScreen> createState() => _ManageMenuScreenState();
}

class _ManageMenuScreenState extends State<ManageMenuScreen> {
  final PocketBaseService pbService = PocketBaseService.instance;
  late Future<List<MenuItemModel>> _menuFuture;

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    if (mounted) {
      setState(() {
        _menuFuture = pbService.menu.getMenu(); // sửa đúng
      });
    }
  }

  void _navigateToForm({MenuItemModel? item}) async {
    final bool? result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => MenuItemFormScreen(menuItem: item),
      ),
    );

    if (result == true && mounted) {
      _loadMenu();
    }
  }

  Future<void> _deleteItem(MenuItemModel item) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận Xóa'),
        content: Text('Bạn có chắc chắn muốn xóa món "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await pbService.menu.deleteMenuItem(item.id);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xóa "${item.name}"'),
            backgroundColor: Colors.green,
          ),
        );

        _loadMenu();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi xóa: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Thực đơn'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToForm(),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),

      body: FutureBuilder<List<MenuItemModel>>(
        future: _menuFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          }

          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('Chưa có món nào.'));
          }

          final foodItems = items
              .where((item) => item.category == MenuItemCategory.food)
              .toList();

          final drinkItems = items
              .where((item) => item.category == MenuItemCategory.drink)
              .toList();

          return RefreshIndicator(
            onRefresh: _loadMenu,
            child: ListView(
              padding: const EdgeInsets.only(
                bottom: 120,
              ), // ⭐⭐ CỰC QUAN TRỌNG — tránh FAB che item cuối
              children: [
                _buildCategorySection(
                  'Món ăn (${foodItems.length})',
                  foodItems,
                ),
                _buildCategorySection(
                  'Thức uống (${drinkItems.length})',
                  drinkItems,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategorySection(String title, List<MenuItemModel> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),

        ListView.builder(
          itemCount: items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final item = items[index];

            return Column(
              children: [
                Dismissible(
                  key: Key(item.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    color: Colors.red,
                    child: const Icon(
                      Icons.delete,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  confirmDismiss: (dir) async {
                    final bool? confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Xác nhận Xóa"),
                        content: Text('Bạn có chắc muốn xóa "${item.name}"?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text("Hủy"),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text(
                              "Xóa",
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await _deleteItem(item);
                    }
                    return false;
                  },

                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),

                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: (item.imageUrl != null)
                          ? Image.network(
                              item.imageUrl!,
                              width: 55,
                              height: 55,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) =>
                                  const Icon(Icons.broken_image, size: 50),
                            )
                          : Container(
                              width: 55,
                              height: 55,
                              color: Colors.grey.shade200,
                              child: const Icon(
                                Icons.fastfood,
                                color: Colors.grey,
                              ),
                            ),
                    ),

                    title: Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        formatCurrency(item.price),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),

                    trailing: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _navigateToForm(item: item),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(left: 85),
                  child: Divider(
                    height: 1,
                    thickness: 0.7,
                    color: Colors.grey.shade300,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
