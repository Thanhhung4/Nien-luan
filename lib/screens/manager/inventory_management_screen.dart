import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:myshop/models/ingredient.dart';
import 'package:myshop/models/ingredient_batch.dart';
import 'package:myshop/services/pocketbase_service.dart';
import 'package:myshop/utils/currency_formatter.dart';

class InventoryManagementScreen extends StatefulWidget {
  const InventoryManagementScreen({super.key});

  @override
  State<InventoryManagementScreen> createState() =>
      _InventoryManagementScreenState();
}

class _InventoryManagementScreenState extends State<InventoryManagementScreen> {
  final pbService = PocketBaseService.instance;
  late Future<List<Ingredient>> _ingredientsFuture;

  @override
  void initState() {
    super.initState();
    _loadIngredients();
  }

  Future<void> _loadIngredients() async {
    if (mounted) {
      setState(() {
        _ingredientsFuture = pbService.inventory.getIngredients();
      });
    }
  }

  Future<void> _syncStock() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await pbService.inventory.recalibrateAllStock();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã đồng bộ dữ liệu kho!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadIngredients();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi đồng bộ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteIngredient(Ingredient ingredient) async {
    try {
      await pbService.inventory.deleteIngredient(ingredient.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xóa ${ingredient.name}'),
            backgroundColor: Colors.green,
          ),
        );
        _loadIngredients();
      }
    } catch (e) {
      if (mounted) {
        _loadIngredients();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xóa: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _disposeBatch(
    IngredientBatch batch,
    Ingredient ingredient,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận tiêu hủy'),
        content: Text(
          'Tiêu hủy lô nhập ngày ${DateFormat('dd/MM').format(batch.importDate)}?\nSố lượng: ${batch.quantity} ${ingredient.unit}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Tiêu hủy'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await pbService.inventory.disposeBatch(
          batchId: batch.id,
          ingredientId: batch.ingredientId,
          ingredientName: ingredient.name,
          quantity: batch.quantity,
          costPerUnit: ingredient.costPerUnit,
        );
        if (mounted) {
          Navigator.pop(context);
          _loadIngredients();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã tiêu hủy và ghi nhận chi phí.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        print(e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Kho'),
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Đồng bộ số liệu',
            onPressed: _syncStock,
          ),
        ],
      ),
      body: FutureBuilder<List<Ingredient>>(
        future: _ingredientsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          }
          final ingredients = snapshot.data ?? [];
          if (ingredients.isEmpty) {
            return const Center(
              child: Text('Kho trống. Hãy thêm nguyên vật liệu.'),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadIngredients,
            child: ListView.builder(
              itemCount: ingredients.length,
              itemBuilder: (context, index) {
                final ingredient = ingredients[index];
                const double lowStockThreshold = 5.0;

                // --- PHẦN SỬA CHỮA QUAN TRỌNG TẠI ĐÂY ---
                return FutureBuilder<List<IngredientBatch>>(
                  future: pbService.inventory.getBatchesForIngredient(
                    ingredient.id,
                  ),
                  builder: (context, batchSnapshot) {
                    // 1. Xử lý trạng thái Đang tải (Loading)
                    if (batchSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: ListTile(
                          leading: const CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                          title: Text(ingredient.name),
                          subtitle: const Text("Đang tải thông tin lô hàng..."),
                        ),
                      );
                    }

                    // 2. Xử lý trạng thái Lỗi (Error) - Để biết tại sao không có data
                    if (batchSnapshot.hasError) {
                      return Card(
                        color: Colors.red.shade50,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.error, color: Colors.red),
                          title: Text(ingredient.name),
                          subtitle: Text("Lỗi tải lô: ${batchSnapshot.error}"),
                        ),
                      );
                    }

                    // 3. Khi đã có dữ liệu (Data)
                    final batches = batchSnapshot.data ?? [];

                    // Kiểm tra lô hết hạn
                    final bool hasExpiredBatch = batches.any(
                      (b) => b.isExpired,
                    );

                    // Logic hiển thị tồn kho
                    bool isOutOfStock = ingredient.stockQuantity <= 0;
                    bool isLowStock =
                        !isOutOfStock &&
                        ingredient.stockQuantity < lowStockThreshold;

                    Color statusColor;
                    IconData statusIcon;
                    String statusText = "";

                    if (isOutOfStock) {
                      statusColor = Colors.red;
                      statusIcon = Icons.remove_shopping_cart;
                      statusText = "HẾT HÀNG";
                    } else if (isLowStock) {
                      statusColor = Colors.orange;
                      statusIcon = Icons.warning_amber;
                      statusText = "Sắp hết";
                    } else {
                      statusColor = Colors.brown;
                      statusIcon = Icons.inventory_2;
                    }

                    if (hasExpiredBatch) {
                      statusIcon = Icons.priority_high;
                    }

                    return Dismissible(
                      key: ValueKey(ingredient.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: const Icon(
                          Icons.delete,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      confirmDismiss: (direction) async {
                        return await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Xác nhận xóa'),
                            content: Text(
                              'Xóa hoàn toàn "${ingredient.name}"?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Hủy'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text(
                                  'Xóa',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      onDismissed: (direction) => _deleteIngredient(ingredient),
                      child: Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: hasExpiredBatch || isOutOfStock
                              ? const BorderSide(color: Colors.red, width: 1.5)
                              : BorderSide.none,
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: (hasExpiredBatch || isOutOfStock)
                                ? Colors.red.shade100
                                : statusColor.withOpacity(0.1),
                            child: Icon(
                              statusIcon,
                              color: (hasExpiredBatch || isOutOfStock)
                                  ? Colors.red
                                  : statusColor,
                            ),
                          ),
                          title: Text(
                            ingredient.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Tổng tồn: ${ingredient.stockQuantity} ${ingredient.unit}',
                                      style: TextStyle(
                                        fontWeight: isOutOfStock
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isOutOfStock
                                            ? Colors.red
                                            : Colors.black87,
                                      ),
                                    ),
                                  ),
                                  if (statusText.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        statusText,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (hasExpiredBatch)
                                const Text(
                                  '⚠️ Có lô hàng quá hạn!',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                              // Hiển thị thêm nếu chưa nhập lô nào
                              if (batches.isEmpty &&
                                  ingredient.stockQuantity > 0)
                                const Text(
                                  '(Chưa nhập lô nào, cần đồng bộ hoặc nhập hàng)',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.add_circle,
                                  color: Colors.green,
                                  size: 32,
                                ),
                                onPressed: () => _showImportDialog(ingredient),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blueGrey,
                                ),
                                onPressed: () => _showIngredientFormDialog(
                                  ingredient: ingredient,
                                ),
                              ),
                            ],
                          ),
                          // CHỈ BẤM ĐƯỢC KHI ĐÃ CÓ DATA
                          onTap: () =>
                              _showBatchDetail(context, ingredient, batches),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showIngredientFormDialog(),
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showBatchDetail(
    BuildContext context,
    Ingredient ing,
    List<IngredientBatch> batches,
  ) {
    final activeBatches = <IngredientBatch>[];
    final expiredBatches = <IngredientBatch>[];
    for (var b in batches) {
      if (b.isExpired)
        expiredBatches.add(b);
      else
        activeBatches.add(b);
    }
    activeBatches.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
    expiredBatches.sort((a, b) => b.expiryDate.compareTo(a.expiryDate));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chi tiết: ${ing.name}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.brown,
                            ),
                          ),
                          Text(
                            'Tổng tồn kho: ${ing.stockQuantity} ${ing.unit}',
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const TabBar(
                labelColor: Colors.brown,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.brown,
                tabs: [
                  Tab(text: "Đang sử dụng", icon: Icon(Icons.inventory)),
                  Tab(
                    text: "Hết hạn (Cần hủy)",
                    icon: Icon(Icons.delete_sweep),
                  ),
                ],
              ),
              const Divider(height: 1),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildBatchList(activeBatches, ing, isExpiredList: false),
                    _buildBatchList(expiredBatches, ing, isExpiredList: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBatchList(
    List<IngredientBatch> batchList,
    Ingredient ing, {
    required bool isExpiredList,
  }) {
    if (batchList.isEmpty)
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isExpiredList ? Icons.thumb_up_alt_outlined : Icons.inbox,
              size: 48,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 8),
            Text(
              isExpiredList
                  ? 'Không có lô hàng hết hạn'
                  : 'Chưa có lô hàng nào',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: batchList.length,
      itemBuilder: (context, index) {
        final batch = batchList[index];
        final difference = batch.expiryDate.difference(DateTime.now());
        final daysLeft = difference.inDays;
        String expiryText;
        Color expiryColor;
        if (daysLeft < 0) {
          expiryText = "Đã quá hạn ${daysLeft.abs()} ngày";
          expiryColor = Colors.red;
        } else if (daysLeft == 0) {
          expiryText = "Hết hạn hôm nay";
          expiryColor = Colors.orange;
        } else {
          expiryText = "Còn lại $daysLeft ngày";
          expiryColor = daysLeft <= 3 ? Colors.orange : Colors.green;
        }

        final bool isOutOfStock = batch.quantity <= 0;
        final usedAmount = batch.initialQuantity - batch.quantity;
        final percent = batch.usagePercent;
        final totalValue = batch.quantity * ing.costPerUnit;

        return Card(
          elevation: 3,
          color: isExpiredList ? Colors.red.shade50 : Colors.white,
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Nhập: ${DateFormat('dd/MM/yyyy').format(batch.importDate)}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.event_busy, size: 14, color: expiryColor),
                        const SizedBox(width: 4),
                        Text(
                          'HSD: ${DateFormat('dd/MM/yyyy').format(batch.expiryDate)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: expiryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isOutOfStock
                                ? "Đã dùng hết (0 ${ing.unit})"
                                : "Còn lại: ${batch.quantity} ${ing.unit}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isOutOfStock
                                  ? Colors.grey
                                  : Colors.black87,
                              decoration: isOutOfStock
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            expiryText,
                            style: TextStyle(
                              color: expiryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: percent,
                              backgroundColor: Colors.grey.shade200,
                              color: isExpiredList
                                  ? Colors.red
                                  : (percent < 0.2 ? Colors.red : Colors.blue),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Nhập: ${batch.initialQuantity.toStringAsFixed(1)} ${ing.unit} | Đã dùng: ${usedAmount.toStringAsFixed(1)} ${ing.unit}",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${formatCurrency(ing.costPerUnit)}/${ing.unit}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          formatCurrency(totalValue),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.brown.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (isExpiredList)
                          SizedBox(
                            height: 30,
                            child: ElevatedButton.icon(
                              onPressed: () => _disposeBatch(batch, ing),
                              icon: const Icon(Icons.delete_forever, size: 16),
                              label: const Text("Tiêu hủy"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                            ),
                          )
                        else if (!isOutOfStock && index == 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              "Đang xuất",
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
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

  void _showImportDialog(Ingredient ingredient) {
    final qtyController = TextEditingController();
    DateTime importDate = DateTime.now();
    DateTime expiryDate = DateTime.now().add(const Duration(days: 30));
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Nhập kho: ${ingredient.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: qtyController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Số lượng',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    "Ngày nhập:",
                    style: TextStyle(fontSize: 14),
                  ),
                  trailing: TextButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(DateFormat('dd/MM/yyyy').format(importDate)),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: importDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => importDate = picked);
                    },
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    "Hạn sử dụng:",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  trailing: TextButton.icon(
                    icon: const Icon(
                      Icons.event_busy,
                      size: 16,
                      color: Colors.red,
                    ),
                    label: Text(
                      DateFormat('dd/MM/yyyy').format(expiryDate),
                      style: const TextStyle(color: Colors.red),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: expiryDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setState(() => expiryDate = picked);
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                final qty = double.tryParse(qtyController.text) ?? 0;
                if (qty > 0) {
                  try {
                    await pbService.inventory.importBatch(
                      ingredientId: ingredient.id,
                      quantity: qty,
                      importDate: importDate,
                      expiryDate: expiryDate,
                    );
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nhập kho thành công!')),
                      );
                      _loadIngredients();
                    }
                  } catch (e) {
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Lỗi: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Nhập hàng'),
            ),
          ],
        ),
      ),
    );
  }

  void _showIngredientFormDialog({Ingredient? ingredient}) {
    showDialog(
      context: context,
      builder: (context) => _IngredientFormDialog(
        ingredient: ingredient,
        onSave: _loadIngredients,
      ),
    );
  }
}

class _IngredientFormDialog extends StatefulWidget {
  final Ingredient? ingredient;
  final VoidCallback onSave;
  const _IngredientFormDialog({this.ingredient, required this.onSave});
  @override
  State<_IngredientFormDialog> createState() => _IngredientFormDialogState();
}

class _IngredientFormDialogState extends State<_IngredientFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final pbService = PocketBaseService.instance;
  bool _isLoading = false;
  late TextEditingController _nameController;
  late TextEditingController _unitController;
  late TextEditingController _costController;
  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.ingredient?.name);
    _unitController = TextEditingController(text: widget.ingredient?.unit);
    _costController = TextEditingController(
      text: widget.ingredient?.costPerUnit.toString() ?? '0',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _costController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final name = _nameController.text;
      final unit = _unitController.text;
      final cost = double.tryParse(_costController.text) ?? 0.0;
      if (widget.ingredient == null) {
        await pbService.inventory.createIngredient(
          name: name,
          unit: unit,
          costPerUnit: cost,
          stockQuantity: 0,
        );
      } else {
        await pbService.inventory.updateIngredient(
          id: widget.ingredient!.id,
          name: name,
          unit: unit,
          costPerUnit: cost,
          stockQuantity: widget.ingredient!.stockQuantity,
        );
      }
      widget.onSave();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.ingredient != null ? 'Sửa Thông tin' : 'Thêm Nguyên vật liệu',
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Tên'),
                validator: (v) => (v == null || v.isEmpty) ? 'Trống' : null,
              ),
              TextFormField(
                controller: _unitController,
                decoration: const InputDecoration(labelText: 'Đơn vị'),
                validator: (v) => (v == null || v.isEmpty) ? 'Trống' : null,
              ),
              TextFormField(
                controller: _costController,
                decoration: const InputDecoration(
                  labelText: 'Giá vốn / đơn vị',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}
