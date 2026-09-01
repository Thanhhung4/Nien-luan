import 'package:flutter/material.dart';
import 'package:myshop/models/cart_item.dart';
import 'package:myshop/models/table.dart';
import 'package:myshop/models/menu_item.dart';
import 'package:myshop/models/order.dart';
import 'package:myshop/services/pocketbase_service.dart';
import 'package:myshop/utils/currency_formatter.dart';
import 'package:myshop/models/order_item_view.dart';

class OrderDetailScreen extends StatefulWidget {
  final TableModel table;
  final OrderModel? existingOrder;

  const OrderDetailScreen({super.key, required this.table, this.existingOrder});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final PocketBaseService pbService = PocketBaseService.instance;
  late Future<List<MenuItemModel>> _menuFuture;

  final Map<String, CartItem> _cart = {};
  double _totalPrice = 0.0;
  bool _isProcessingOrder = false;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  bool _isLoadingExistingCart = false;

  @override
  void initState() {
    super.initState();
    _menuFuture = pbService.menu.getMenu();
    _searchController.addListener(_onSearchChanged);

    if (widget.existingOrder != null) {
      _loadExistingCart();
    }
  }

  Future<void> _loadExistingCart() async {
    if (widget.existingOrder == null) return;

    setState(() {
      _isLoadingExistingCart = true;
    });
    try {
      final List<OrderItemView> existingItems = await pbService
          .getOrderItemsWithDetails(widget.existingOrder!.id);

      final Map<String, CartItem> initialCart = {};
      for (final itemView in existingItems) {
        if (!_cart.containsKey(itemView.menuItem.id)) {
          initialCart[itemView.menuItem.id] = CartItem(
            item: itemView.menuItem,
            quantity: itemView.quantity,
            notes: itemView.notes,
          );
        }
      }

      setState(() {
        _cart.addAll(initialCart);
        _calculateTotalPrice();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải giỏ hàng cũ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingExistingCart = false;
        });
      }
    }
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

  void _incrementItem(MenuItemModel item) {
    if (!item.inStock) return; // Chặn nếu hết hàng
    setState(() {
      if (_cart.containsKey(item.id)) {
        _cart[item.id]!.quantity++;
      } else {
        _cart[item.id] = CartItem(item: item, quantity: 1);
      }
      _calculateTotalPrice();
    });
  }

  void _decrementItem(MenuItemModel item) {
    setState(() {
      if (_cart.containsKey(item.id)) {
        if (_cart[item.id]!.quantity > 1) {
          _cart[item.id]!.quantity--;
        } else {
          _cart.remove(item.id);
        }
        _calculateTotalPrice();
      }
    });
  }

  void _calculateTotalPrice() {
    double total = 0.0;
    for (final cartItem in _cart.values) {
      total += cartItem.subtotal;
    }
    setState(() {
      _totalPrice = total;
    });
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
    setState(() {
      _isProcessingOrder = true;
    });

    try {
      final bool isAddingMore = widget.existingOrder != null;
      String orderId;

      if (isAddingMore) {
        orderId = widget.existingOrder!.id;
        final existingItemViews = await pbService.getOrderItemsWithDetails(
          orderId,
        );
        final Map<String, OrderItemView> existingItemsMap = {
          for (var view in existingItemViews) view.menuItem.id: view,
        };

        // 1) Xóa món đã có trong DB nhưng người dùng bỏ khỏi giỏ
        for (final existing in existingItemViews) {
          if (!_cart.containsKey(existing.menuItem.id)) {
            await pbService.deleteOrderItemRecord(existing.id);
          }
        }

        // 2) Update tăng/giảm số lượng + ghi chú, và tạo món mới nếu chưa có
        for (final cartItem in _cart.values) {
          final existing = existingItemsMap[cartItem.item.id];
          if (existing == null) {
            await pbService.createOrderItemRecord(
              orderId: orderId,
              menuItemId: cartItem.item.id,
              quantity: cartItem.quantity,
              price: cartItem.item.price,
              notes: cartItem.notes,
            );
          } else {
            await pbService.updateOrderItemRecord(
              orderItemId: existing.id,
              quantity: cartItem.quantity,
              notes: cartItem.notes,
            );
          }
        }

        final allItems = await pbService.getOrderItemsWithDetails(orderId);
        final newTotal = allItems.fold<double>(
          0.0,
          (sum, item) => sum + item.subtotal,
        );
        await pbService.updateOrderTotalPrice(orderId, newTotal);
      } else {
        orderId = await pbService.createOrderRecord(
          _totalPrice,
          tableId: widget.table.id,
        );
        for (final cartItem in _cart.values) {
          await pbService.createOrderItemRecord(
            orderId: orderId,
            menuItemId: cartItem.item.id,
            quantity: cartItem.quantity,
            price: cartItem.item.price,
            notes: cartItem.notes,
          );
        }
        await pbService.updateTableStatus(widget.table.id, 'occupied');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã cập nhật hóa đơn cho ${widget.table.name}!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi xử lý hóa đơn: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingOrder = false;
        });
      }
    }
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
    final bool isAddingMore = widget.existingOrder != null;
    final String appBarTitle = isAddingMore
        ? "Gọi thêm cho ${widget.table.name}"
        : "Hóa đơn cho ${widget.table.name}";
    final Color appBarColor = isAddingMore
        ? Colors.red.shade400
        : (widget.table.isOccupied
              ? Colors.red.shade400
              : Colors.green.shade400);

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        backgroundColor: appBarColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          if (_isLoadingExistingCart)
            const Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          Expanded(
            child: FutureBuilder<List<MenuItemModel>>(
              future: _menuFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !_isLoadingExistingCart) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Lỗi: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.done) {
                  final menuItems = snapshot.data ?? [];
                  if (menuItems.isEmpty) {
                    return const Center(child: Text('Thực đơn trống.'));
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
                    return const Center(child: Text('Không tìm thấy món.'));
                  }

                  final foodItems = filteredItems
                      .where((item) => item.category == MenuItemCategory.food)
                      .toList();
                  final drinkItems = filteredItems
                      .where((item) => item.category == MenuItemCategory.drink)
                      .toList();

                  return ListView(
                    padding: const EdgeInsets.all(8.0),
                    children: [
                      if (foodItems.isNotEmpty)
                        _buildCategoryHeader("Món Ăn (${foodItems.length})"),
                      if (foodItems.isNotEmpty) _buildMenuListView(foodItems),
                      if (drinkItems.isNotEmpty)
                        _buildCategoryHeader(
                          "Thức Uống (${drinkItems.length})",
                        ),
                      if (drinkItems.isNotEmpty) _buildMenuListView(drinkItems),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          _buildCartSummaryBar(isAddingMore),
        ],
      ),
    );
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

        // -- LOGIC HẾT HÀNG --
        final bool isOutOfStock = !item.inStock;

        return Card(
          elevation: 2.0,
          margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
          color: isOutOfStock
              ? Colors.grey.shade100
              : Colors.white, // Nền xám nếu hết hàng
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
                      // Gạch ngang tên nếu hết hàng
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
              '${formatCurrency(item.price)}${item.unit.isNotEmpty ? ' / ${item.unit}' : ''}${hasNote ? '\nGhi chú: $note' : ''}',
              style: TextStyle(color: hasNote ? Colors.deepPurple : null),
            ),
            isThreeLine: hasNote,
            trailing: isOutOfStock
                ? const SizedBox(width: 1) // Ẩn nút nếu hết hàng
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

  Widget _buildCartSummaryBar(bool isAddingMore) {
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
    final String buttonText = isAddingMore ? 'OK' : 'OK (Tạo Hóa Đơn)';
    final Color buttonColor = isAddingMore ? Colors.blue : Colors.green;

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tổng ($totalItems món):',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  formatCurrency(_totalPrice),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.check_circle),
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(buttonText, maxLines: 1),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
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
