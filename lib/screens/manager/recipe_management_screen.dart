// [DÁN TOÀN BỘ CODE NÀY VÀO lib/screens/manager/recipe_management_screen.dart]

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:myshop/models/ingredient.dart';
import 'package:myshop/models/menu_item.dart';
import 'package:myshop/models/menu_item_ingredient.dart';
import 'package:myshop/services/pocketbase_service.dart';
import 'package:myshop/utils/currency_formatter.dart';

class RecipeManagementScreen extends StatefulWidget {
  final MenuItemModel menuItem;
  const RecipeManagementScreen({super.key, required this.menuItem});

  @override
  State<RecipeManagementScreen> createState() => _RecipeManagementScreenState();
}

class _RecipeManagementScreenState extends State<RecipeManagementScreen> {
  final pbService = PocketBaseService.instance;

  late Future<List<MenuItemIngredient>> _recipeFuture;
  late Future<List<Ingredient>> _allIngredientsFuture;

  List<Ingredient> _allIngredientsCache = [];
  double _totalCost = 0.0;
  bool _isSavingCost = false;

  @override
  void initState() {
    super.initState();
    _loadAllIngredients();
    _loadRecipe();
  }

  Future<void> _loadAllIngredients() async {
    _allIngredientsFuture = pbService.inventory.getIngredients();
    try {
      _allIngredientsCache = await _allIngredientsFuture;
    } catch (_) {
      // ignore, snack handled elsewhere if needed
    }
  }

  Future<void> _loadRecipe() async {
    setState(() {
      _recipeFuture = pbService.inventory
          .getIngredientsForMenuItem(widget.menuItem.id)
          .then((recipeItems) {
            _calculateTotalCost(recipeItems);
            return recipeItems;
          });
    });
  }

  void _calculateTotalCost(List<MenuItemIngredient> recipeItems) {
    final total = recipeItems.fold<double>(0.0, (sum, i) => sum + i.cost);
    setState(() => _totalCost = total);
  }

  Future<void> _updateMenuItemCost() async {
    setState(() => _isSavingCost = true);

    try {
      await pbService.menu.updateMenuItem(
        id: widget.menuItem.id,
        name: widget.menuItem.name,
        price: widget.menuItem.price,
        category: widget.menuItem.category == MenuItemCategory.food
            ? 'food'
            : 'drink',
        inStock: widget.menuItem.inStock,
        unit: widget.menuItem.unit,
        description: widget.menuItem.description,
        currentImageFilename: widget.menuItem.image,
        cost: _totalCost,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã cập nhật tổng giá vốn!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi cập nhật giá vốn: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingCost = false);
    }
  }

  Future<void> _addIngredient() async {
    final recipeItems = await _recipeFuture;

    // Không cho thêm trùng nguyên liệu
    final usedIds = recipeItems.map((e) => e.ingredient.id).toSet();
    final availableIngredients = _allIngredientsCache
        .where((ing) => !usedIds.contains(ing.id))
        .toList();

    if (availableIngredients.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tất cả nguyên liệu đã được thêm!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _IngredientDialog(
        title: "Thêm Nguyên liệu",
        allIngredients: availableIngredients,
      ),
    );

    if (result != null) {
      try {
        await pbService.inventory.createMenuItemIngredient(
          menuItemId: widget.menuItem.id,
          ingredientId: result['ingredient'].id,
          quantityNeeded: result['quantity'],
        );
        _loadRecipe();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi thêm nguyên liệu: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _editIngredient(MenuItemIngredient item) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _IngredientDialog(
        title: "Sửa số lượng",
        ingredientFixed: item.ingredient,
        initialQty: item.quantityNeeded,
      ),
    );

    if (result != null) {
      try {
        // Gọi đúng service của bạn
        await pbService.inventory.updateMenuItemIngredient(
          recipeItemId: item.id,
          quantityNeeded: result['quantity'],
        );
        _loadRecipe();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi chỉnh sửa: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteIngredient(String recipeItemId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text(
          'Bạn có chắc chắn muốn xóa nguyên liệu này khỏi công thức?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await pbService.inventory.deleteMenuItemIngredient(recipeItemId);
      _loadRecipe();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi xóa nguyên liệu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ------------------------- UI ------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Công thức: ${widget.menuItem.name}'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _isSavingCost
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : const Icon(Icons.save),
            onPressed: _isSavingCost ? null : _updateMenuItemCost,
          ),
        ],
      ),
      body: FutureBuilder<List<MenuItemIngredient>>(
        future: _recipeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Lỗi tải công thức: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            );
          }

          final recipeItems = snapshot.data ?? [];

          return Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(
                    bottom: 96.0,
                  ), // chừa chỗ cho FAB
                  child: recipeItems.isEmpty
                      ? const Center(child: Text('Chưa có nguyên liệu nào.'))
                      : ListView.separated(
                          itemCount: recipeItems.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: Colors.grey.shade300,
                            indent: 16,
                            endIndent: 16,
                          ),
                          itemBuilder: (context, index) {
                            final item = recipeItems[index];

                            return Dismissible(
                              key: ValueKey(item.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: const Icon(
                                  Icons.delete,
                                  color: Colors.white,
                                ),
                              ),
                              confirmDismiss: (direction) async {
                                // show confirm dialog, then delete via _deleteIngredient
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Xác nhận xóa'),
                                    content: Text(
                                      'Bạn muốn xóa ${item.ingredient.name} khỏi công thức?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: const Text('Hủy'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(true),
                                        child: const Text(
                                          'Xóa',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  await _deleteIngredient(item.id);
                                }
                                return false; // return false để không auto remove widget (we reload list ourselves)
                              },
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.orange.shade100,
                                  child: Text(
                                    item.ingredient.unit,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                                title: Text(
                                  item.ingredient.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  '${item.quantityNeeded} ${item.ingredient.unit}',
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                                onTap: () => _editIngredient(item),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    color: Colors.lightBlueAccent,
                                  ),
                                  onPressed: () => _editIngredient(item),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),

              // Tổng giá vốn
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 6,
                      offset: const Offset(0, -2),
                      color: Colors.grey.withOpacity(0.12),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tổng giá vốn:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      formatCurrency(_totalCost),
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.deepPurple.shade600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addIngredient,
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// --------------------------------------------------------------
//  DIALOG THÊM / SỬA NGUYÊN LIỆU
// --------------------------------------------------------------

class _IngredientDialog extends StatefulWidget {
  final String title;
  final List<Ingredient>? allIngredients; // null = edit mode
  final Ingredient? ingredientFixed; // edit mode
  final double? initialQty;

  const _IngredientDialog({
    required this.title,
    this.allIngredients,
    this.ingredientFixed,
    this.initialQty,
  });

  @override
  State<_IngredientDialog> createState() => _IngredientDialogState();
}

class _IngredientDialogState extends State<_IngredientDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  Ingredient? _selectedIngredient;

  @override
  void initState() {
    super.initState();
    _selectedIngredient = widget.ingredientFixed;
    if (widget.initialQty != null) {
      _quantityController.text = widget.initialQty.toString();
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final available = widget.allIngredients ?? [];

    // If in add mode but no available ingredients - show simple message
    if (widget.allIngredients != null && available.isEmpty) {
      return AlertDialog(
        title: const Text('Không có nguyên liệu'),
        content: const Text('Không còn nguyên liệu khả dụng để thêm.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.allIngredients != null)
              DropdownButtonFormField<Ingredient>(
                value: _selectedIngredient,
                decoration: const InputDecoration(
                  labelText: 'Chọn Nguyên liệu',
                ),
                items: available
                    .map(
                      (ing) => DropdownMenuItem(
                        value: ing,
                        child: Text('${ing.name} (${ing.unit})'),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _selectedIngredient = val),
                validator: (val) =>
                    val == null ? 'Vui lòng chọn nguyên liệu' : null,
              )
            else
              // show fixed ingredient name when editing
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.ingredientFixed?.name ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.ingredientFixed?.unit ?? '',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),

            TextFormField(
              controller: _quantityController,
              decoration: InputDecoration(
                labelText:
                    'Số lượng (${_selectedIngredient?.unit ?? widget.ingredientFixed?.unit ?? '...'})',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*')),
              ],
              validator: (val) {
                if (val == null || val.isEmpty) return 'Không được trống';
                if (double.tryParse(val) == null) return 'Phải là số';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop({
                'ingredient': _selectedIngredient ?? widget.ingredientFixed,
                'quantity': double.parse(_quantityController.text),
              });
            }
          },
          child: const Text('Xong'),
        ),
      ],
    );
  }
}
