import 'package:flutter/foundation.dart';
import '../models/order.dart';
import '../models/order_view.dart';
import '../models/cart_item.dart';
// TODO: Uncomment when implementing actual PocketBase integration
// import '../services/pocketbase_service.dart';

// Order Status Enum
enum OrderStatus { pending, preparing, ready, completed, cancelled }

class OrderProvider extends ChangeNotifier {
  // TODO: Uncomment when implementing actual PocketBase integration
  // final PocketBaseService _pbService = PocketBaseService.instance;

  // State variables
  List<OrderViewModel> _orders = [];
  List<OrderViewModel> _activeOrders = [];
  List<OrderViewModel> _completedOrders = [];
  bool _isLoading = false;
  String? _error;

  // Real-time order tracking
  OrderViewModel? _currentOrder;
  final Map<String, OrderStatus> _orderStatuses = {};

  // Getters
  List<OrderViewModel> get orders => _orders;
  List<OrderViewModel> get activeOrders => _activeOrders;
  List<OrderViewModel> get completedOrders => _completedOrders;
  bool get isLoading => _isLoading;
  String? get error => _error;
  OrderViewModel? get currentOrder => _currentOrder;

  // Filter orders by status
  List<OrderViewModel> get pendingOrders => _activeOrders
      .where((order) => _orderStatuses[order.id] == OrderStatus.pending)
      .toList();

  List<OrderViewModel> get preparingOrders => _activeOrders
      .where((order) => _orderStatuses[order.id] == OrderStatus.preparing)
      .toList();

  List<OrderViewModel> get readyOrders => _activeOrders
      .where((order) => _orderStatuses[order.id] == OrderStatus.ready)
      .toList();

  // Statistics
  int get totalOrdersToday =>
      _orders.where((order) => order.created.day == DateTime.now().day).length;

  double get totalRevenueToday => _completedOrders
      .where((order) => order.created.day == DateTime.now().day)
      .fold(0.0, (sum, order) => sum + order.totalPrice);

  /// Load all orders
  Future<void> loadOrders() async {
    _setLoading(true);
    try {
      // TODO: Implement actual service call when PocketBase service is ready
      // _orders = await _pbService.getOrderViews();
      _orders = []; // Temporary placeholder
      _updateOrderLists();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  /// Create new order from cart
  Future<bool> createOrder({
    required List<CartItem> cartItems,
    String? customerName,
    String? notes,
    String? tableId,
  }) async {
    _setLoading(true);
    try {
      final totalAmount = cartItems.fold(
        0.0,
        (sum, item) => sum + item.subtotal,
      );

      final order = OrderModel(
        id: '',
        tableId: tableId ?? 'takeaway',
        totalPrice: totalAmount,
        createdById: null,
        created: DateTime.now(),
        updated: DateTime.now(),
      );

      // TODO: Implement actual order creation
      // final success = await _pbService.createOrder(order, cartItems);
      debugPrint('Creating order: ${order.totalPrice}');
      final success = true; // Temporary placeholder

      if (success) {
        await loadOrders(); // Refresh orders
      }
      return success;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Update order status
  Future<bool> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    try {
      // TODO: Implement actual status update
      // final success = await _pbService.updateOrderStatus(orderId, newStatus);
      final success = true; // Temporary placeholder

      if (success) {
        _orderStatuses[orderId] = newStatus;
        _updateOrderLists();
        notifyOrderStatusChange(orderId, newStatus);
        notifyListeners();
      }
      return success;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  /// Mark order as completed
  Future<bool> completeOrder(String orderId) async {
    return await updateOrderStatus(orderId, OrderStatus.completed);
  }

  /// Cancel order
  Future<bool> cancelOrder(String orderId) async {
    return await updateOrderStatus(orderId, OrderStatus.cancelled);
  }

  /// Get order by ID
  OrderViewModel? getOrderById(String orderId) {
    try {
      return _orders.firstWhere((order) => order.id == orderId);
    } catch (e) {
      return null;
    }
  }

  /// Search orders by customer name or order ID
  List<OrderViewModel> searchOrders(String query) {
    if (query.isEmpty) return _orders;

    return _orders.where((order) {
      final customerName = order.createdByUsername.toLowerCase();
      final orderId = order.id.toLowerCase();
      final searchQuery = query.toLowerCase();

      return customerName.contains(searchQuery) ||
          orderId.contains(searchQuery);
    }).toList();
  }

  /// Get orders by date range
  List<OrderViewModel> getOrdersByDateRange(DateTime start, DateTime end) {
    return _orders.where((order) {
      return order.created.isAfter(start.subtract(const Duration(days: 1))) &&
          order.created.isBefore(end.add(const Duration(days: 1)));
    }).toList();
  }

  /// Real-time order tracking
  void startOrderTracking(String orderId) {
    _currentOrder = getOrderById(orderId);
    notifyListeners();
  }

  void stopOrderTracking() {
    _currentOrder = null;
    notifyListeners();
  }

  /// Get order status for specific order
  OrderStatus? getOrderStatus(String orderId) {
    return _orderStatuses[orderId];
  }

  /// Set order status (for internal use)
  void setOrderStatus(String orderId, OrderStatus status) {
    _orderStatuses[orderId] = status;
    _updateOrderLists();
    notifyListeners();
  }

  /// Refresh orders
  Future<void> refreshOrders() async {
    await loadOrders();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Add notification for order status changes
  void notifyOrderStatusChange(String orderId, OrderStatus newStatus) {
    // TODO: Implement push notification or in-app notification
    debugPrint('Order $orderId status changed to $newStatus');
  }

  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _updateOrderLists() {
    _activeOrders = _orders
        .where(
          (order) =>
              _orderStatuses[order.id] != OrderStatus.completed &&
              _orderStatuses[order.id] != OrderStatus.cancelled,
        )
        .toList();

    _completedOrders = _orders
        .where((order) => _orderStatuses[order.id] == OrderStatus.completed)
        .toList();

    notifyListeners();
  }
}
