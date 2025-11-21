import 'package:flutter/material.dart';
import 'package:myshop/models/cart_item.dart';
import 'package:myshop/models/menu_item.dart';
import 'package:myshop/screens/auth/login_screen.dart';
import 'package:myshop/screens/employee/employee_profile_screen.dart';
import 'package:myshop/screens/employee/order_details_screen.dart';
import 'package:myshop/screens/order/completed_orders_screen.dart';
import 'package:myshop/services/pocketbase_service.dart';
import 'package:myshop/utils/currency_formatter.dart';

class EmployeeHome extends StatefulWidget {
  const EmployeeHome({super.key});

  @override
  State<EmployeeHome> createState() => _EmployeeHomeState();
}

class _EmployeeHomeState extends State<EmployeeHome> {
  final PocketBaseService pbService = PocketBaseService.instance;
  late Future<List<MenuItemModel>> _menuFuture;

  final TextEditingController _searchController = TextEditingController();
  final Map<String, CartItem> _cart = {};

  String _searchQuery = '';
  double _totalPrice = 0.0;
  bool _isProcessingOrder = false;

  @override
  void initState() {
    super.initState();
    _menuFuture = pbService.menu.getMenu();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  Future<void> _refreshMenu() async {
    setState(() {
      _menuFuture = pbService.menu.getMenu();
    });
    try {
      await _menuFuture;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi tải thực đơn: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _incrementItem(MenuItemModel item) {
    if (!item.inStock) return;
    setState(() {
      if (_cart.containsKey(item.id)) {
        _cart[item.id]!.quantity++;
      } else {
        _cart[item.id] = CartItem(item: item);
      }
      _calculateTotalPrice();
    });
  }

  void _decrementItem(MenuItemModel item) {
    setState(() {
      if (!_cart.containsKey(item.id)) return;
      if (_cart[item.id]!.quantity > 1) {
        _cart[item.id]!.quantity--;
      } else {
        _cart.remove(item.id);
      }
      _calculateTotalPrice();
    });
  }

  void _calculateTotalPrice() {
    double total = 0.0;
    for (final cartItem in _cart.values) {
      total += cartItem.subtotal;
    }
    _totalPrice = total;
  }

  Future<void> _processOrder() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Giỏ hàng đang trống. Vui lòng chọn món.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Chuyển đến trang chi tiết đặt món
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) =>
                OrderDetailsScreen(cartItems: _cart.values.toList()),
          ),
        )
        .then((_) {
          // Sau khi quay về từ trang chi tiết, clear giỏ hàng
          setState(() {
            _cart.clear();
            _totalPrice = 0.0;
          });
        });
  }

  void _logout(BuildContext context) {
    pbService.logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  void _navigateToCompletedOrders() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const CompletedOrdersScreen()),
    );
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const EmployeeProfileScreen()),
    );
  }

  Future<void> _showAddNoteDialog(CartItem cartItem) async {
    final noteController = TextEditingController(text: cartItem.notes);
    final newNote = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ghi chú cho "${cartItem.item.name}"'),
        content: TextField(
          controller: noteController,
          decoration: const InputDecoration(
            hintText: 'Ví dụ: ít đường, không cay...',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(noteController.text);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (newNote != null) {
      setState(() {
        cartItem.notes = newNote;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tạo hóa đơn"),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.account_circle, color: Colors.white, size: 30),
          tooltip: 'Tài khoản',
          onPressed: _openProfile,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long, color: Colors.white),
            tooltip: 'Hóa đơn đã hoàn thành',
            onPressed: _navigateToCompletedOrders,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Đăng xuất',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: FutureBuilder<List<MenuItemModel>>(
              future: _menuFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
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
                            'Lỗi tải thực đơn: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _refreshMenu,
                            child: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final menuItems = snapshot.data ?? [];
                if (menuItems.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _refreshMenu,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        Padding(
                          padding: EdgeInsets.only(top: 120),
                          child: Center(
                            child: Text(
                              'Thực đơn đang trống. Vui lòng thêm món trên PocketBase.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final filteredItems = _searchQuery.isEmpty
                    ? menuItems
                    : menuItems
                          .where(
                            (item) => item.name.toLowerCase().contains(
                              _searchQuery.toLowerCase(),
                            ),
                          )
                          .toList();

                if (filteredItems.isEmpty) {
                  return const Center(
                    child: Text('Không tìm thấy món phù hợp với tìm kiếm.'),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refreshMenu,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 16),
                    children: _buildMenuSections(filteredItems),
                  ),
                );
              },
            ),
          ),
          _buildCartSummaryBar(),
        ],
      ),
    );
  }

  List<Widget> _buildMenuSections(List<MenuItemModel> items) {
    final foodItems = items
        .where((item) => item.category == MenuItemCategory.food)
        .toList();
    final drinkItems = items
        .where((item) => item.category == MenuItemCategory.drink)
        .toList();

    final List<Widget> sections = [];

    if (foodItems.isNotEmpty) {
      sections.add(_buildCategoryHeader('Món ăn (${foodItems.length})'));
      sections.add(_buildMenuListView(foodItems));
    }
    if (drinkItems.isNotEmpty) {
      sections.add(_buildCategoryHeader('Thức uống (${drinkItems.length})'));
      sections.add(_buildMenuListView(drinkItems));
    }

    if (sections.isEmpty) {
      sections.add(
        const Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(child: Text('Không có món nào khả dụng.')),
        ),
      );
    }

    return sections;
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          labelText: 'Tìm kiếm món...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _searchController.clear(),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildCategoryHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.deepPurple,
        ),
      ),
    );
  }

  Widget _buildMenuListView(List<MenuItemModel> items) {
    return ListView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final item = items[index];
        final CartItem? cartItem = _cart[item.id];
        final int quantityInCart = cartItem?.quantity ?? 0;
        final String? note = cartItem?.notes;
        final bool hasNote = note != null && note.isNotEmpty;
        final bool isOutOfStock = !item.inStock;

        return Card(
          elevation: 2.0,
          margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
          color: isOutOfStock ? Colors.grey.shade200 : Colors.white,
          child: ListTile(
            leading: Opacity(
              opacity: isOutOfStock ? 0.5 : 1.0,
              child: (item.imageUrl != null)
                  ? Image.network(
                      item.imageUrl!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image, size: 50),
                    )
                  : const SizedBox(
                      width: 50,
                      height: 50,
                      child: Icon(Icons.fastfood, color: Colors.grey),
                    ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration: isOutOfStock
                          ? TextDecoration.lineThrough
                          : null,
                      color: isOutOfStock ? Colors.grey : Colors.black,
                    ),
                  ),
                ),
                if (isOutOfStock)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      "HẾT HÀNG",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Text(
              '${formatCurrency(item.price)}${item.unit.isNotEmpty ? ' / ${item.unit}' : ''}'
              '${hasNote ? '\nGhi chú: $note' : ''}',
              style: TextStyle(color: hasNote ? Colors.deepPurple : null),
            ),
            isThreeLine: hasNote,
            trailing: isOutOfStock
                ? const SizedBox(width: 1)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (quantityInCart > 0)
                        IconButton(
                          icon: Icon(
                            Icons.edit_note,
                            color: hasNote ? Colors.deepPurple : Colors.grey,
                          ),
                          onPressed: () => _showAddNoteDialog(cartItem!),
                        ),
                      if (quantityInCart == 0)
                        IconButton(
                          icon: const Icon(
                            Icons.add_shopping_cart,
                            color: Colors.green,
                          ),
                          onPressed: () => _incrementItem(item),
                        )
                      else
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.remove,
                                color: Colors.red.shade700,
                              ),
                              onPressed: () => _decrementItem(item),
                            ),
                            Text(
                              '$quantityInCart',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, color: Colors.green),
                              onPressed: () => _incrementItem(item),
                            ),
                          ],
                        ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildCartSummaryBar() {
    if (_isProcessingOrder) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_cart.isEmpty) return const SizedBox.shrink();

    final int totalItems = _cart.values.fold(
      0,
      (sum, item) => sum + item.quantity,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tổng ($totalItems món):',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              Text(
                formatCurrency(_totalPrice),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
            ],
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.check_circle),
            label: const Text('Tạo hóa đơn'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: _processOrder,
          ),
        ],
      ),
    );
  }
}
