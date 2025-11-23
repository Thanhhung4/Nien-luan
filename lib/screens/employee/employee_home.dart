import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:myshop/models/cart_item.dart';
import 'package:myshop/models/menu_item.dart';
import 'package:myshop/screens/auth/login_screen.dart';
import 'package:myshop/screens/employee/employee_profile_screen.dart';
import 'package:myshop/screens/employee/order_details_screen.dart';
import 'package:myshop/screens/employee/notification_screen.dart';
import 'package:myshop/screens/order/completed_orders_screen.dart';
import 'package:myshop/services/pocketbase_service.dart';
import 'package:myshop/utils/currency_formatter.dart';
import '../../providers/cart_provider.dart';
import '../../providers/menu_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';

class EmployeeHome extends StatefulWidget {
  const EmployeeHome({super.key});

  @override
  State<EmployeeHome> createState() => _EmployeeHomeState();
}

class _EmployeeHomeState extends State<EmployeeHome> {
  final PocketBaseService pbService = PocketBaseService.instance;

  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  bool _isProcessingOrder = false;
  Timer? _notificationTimer;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    // Load menu khi vào trang
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MenuProvider>().loadMenu();
      _loadNotificationsFromDatabase();

      // Set up periodic notification check (every 30 seconds)
      _notificationTimer = Timer.periodic(
        const Duration(seconds: 30),
        (timer) => _loadNotificationsFromDatabase(),
      );
    });
  }

  // Load notifications từ database vào NotificationProvider
  Future<void> _loadNotificationsFromDatabase() async {
    try {
      final notifications = await pbService.notifications.getNotifications();
      final notificationProvider = context.read<NotificationProvider>();

      // Clear existing notifications and add only unread ones from database
      notificationProvider.clearAll();

      for (final notif in notifications) {
        // Only add unread notifications to show badge
        if (!notif.isRead) {
          notificationProvider.addNotification(
            title: notif.title,
            message: notif.content,
            type: NotificationType.system, // Default type
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _notificationTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  Future<void> _refreshMenu() async {
    await context.read<MenuProvider>().refreshMenu();
  }

  void _incrementItem(MenuItemModel item) {
    if (!item.inStock) return;
    context.read<CartProvider>().addItem(item);
  }

  void _decrementItem(MenuItemModel item) {
    context.read<CartProvider>().removeItem(item.id);
  }

  Future<void> _processOrder() async {
    final cartProvider = context.read<CartProvider>();
    if (cartProvider.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Giỏ hàng đang trống. Vui lòng chọn món.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Chuyển đến trang chi tiết đặt món
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            OrderDetailsScreen(cartItems: cartProvider.cartItems),
      ),
    );
    // Removed: cartProvider.clear() - Keep cart items when returning
  }

  void _logout(BuildContext context) {
    context.read<AuthProvider>().logout();
    context.read<CartProvider>().clear(); // Clear cart khi logout
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

  void _openNotifications() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(builder: (context) => const NotificationScreen()),
        )
        .then((_) {
          // Mark all as read when returning from notification screen
          context.read<NotificationProvider>().markAllAsRead();
        });
  }

  Future<void> _showAddNoteDialog(CartItem cartItem) async {
    final cartProvider = context.read<CartProvider>();
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
      cartProvider.updateNotes(cartItem.item.id, newNote);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Trang chủ"),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.account_circle, color: Colors.white, size: 30),
          tooltip: 'Tài khoản',
          onPressed: _openProfile,
        ),
        actions: [
          // Bell icon with notification badge
          Consumer<NotificationProvider>(
            builder: (context, notificationProvider, child) {
              final unreadCount = notificationProvider.unreadCount;
              debugPrint('Badge rebuilt: unreadCount = $unreadCount');
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications, color: Colors.white),
                    tooltip: 'Thông báo',
                    onPressed: _openNotifications,
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
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
            child: Consumer<MenuProvider>(
              builder: (context, menuProvider, child) {
                if (menuProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (menuProvider.error != null) {
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
                            'Lỗi tải thực đơn: ${menuProvider.error}',
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

                final menuItems = menuProvider.menuItems;
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
                    : menuProvider.searchItems(_searchQuery);

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
    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        return ListView.builder(
          itemCount: items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final item = items[index];
            final CartItem? cartItem = cartProvider.getItem(item.id);
            final int quantityInCart = cartItem?.quantity ?? 0;
            final String? note = cartItem?.notes;
            final bool hasNote = note != null && note.isNotEmpty;
            final bool isOutOfStock = !item.inStock;

            return Card(
              elevation: 2.0,
              margin: const EdgeInsets.symmetric(
                vertical: 4.0,
                horizontal: 8.0,
              ),
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
                                color: hasNote
                                    ? Colors.deepPurple
                                    : Colors.grey,
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
                                  icon: const Icon(
                                    Icons.add,
                                    color: Colors.green,
                                  ),
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

    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        if (cartProvider.isEmpty) return const SizedBox.shrink();

        final int totalItems = cartProvider.itemCount;

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
                    formatCurrency(cartProvider.totalAmount),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                onPressed: _processOrder,
              ),
            ],
          ),
        );
      },
    );
  }
}
