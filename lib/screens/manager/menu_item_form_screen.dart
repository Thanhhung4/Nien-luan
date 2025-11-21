// [DÁN TOÀN BỘ CODE NÀY VÀO lib/screens/manager/menu_item_form_screen.dart]

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:myshop/models/menu_item.dart';
import 'package:myshop/services/pocketbase_service.dart';
import 'package:myshop/screens/manager/recipe_management_screen.dart';
import 'package:myshop/utils/currency_formatter.dart'; // <--- SỬA LỖI 1
import 'package:myshop/utils/constants.dart';

class MenuItemFormScreen extends StatefulWidget {
  final MenuItemModel? menuItem;

  const MenuItemFormScreen({super.key, this.menuItem});

  @override
  State<MenuItemFormScreen> createState() => _MenuItemFormScreenState();
}

class _MenuItemFormScreenState extends State<MenuItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final pbService = PocketBaseService.instance;
  bool _isLoading = false;

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController
  _priceController; // Vẫn dùng để nhập giá trong Dialog
  late TextEditingController _descriptionController;

  // Selected values
  String? _selectedUnit;

  // State
  MenuItemCategory _selectedCategory = MenuItemCategory.food;
  bool _inStock = true;
  XFile? _selectedImage;
  String? _existingImageUrl;

  // Sửa thành state để UI cập nhật
  late double _currentPrice;
  late double _currentCost;

  bool get _isEditing => widget.menuItem != null;

  @override
  void initState() {
    super.initState();
    final item = widget.menuItem;
    _nameController = TextEditingController(text: item?.name);
    _priceController = TextEditingController(
      text: item?.price.toString() ?? '0',
    );
    _descriptionController = TextEditingController(text: item?.description);

    _selectedUnit = item?.unit;

    _currentPrice = item?.price ?? 0.0;
    _currentCost = item?.cost ?? 0.0;

    _selectedCategory = item?.category ?? MenuItemCategory.food;
    _inStock = item?.inStock ?? true;
    _existingImageUrl = item?.imageUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = image;
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoading = true;
    });

    try {
      final name = _nameController.text;
      final price = _currentPrice; // Lấy từ state
      final unit = _selectedUnit ?? '';
      final description = _descriptionController.text;
      final cost = _currentCost; // Lấy từ state
      final category = _selectedCategory == MenuItemCategory.food
          ? 'food'
          : 'drink';

      File? imageFile = _selectedImage != null
          ? File(_selectedImage!.path)
          : null;

      if (_isEditing) {
        await pbService.menu.updateMenuItem(
          id: widget.menuItem!.id,
          name: name,
          price: price,
          category: category,
          inStock: _inStock,
          unit: unit,
          description: description,
          image: imageFile,
          currentImageFilename: widget.menuItem!.image,
          cost: cost,
        );
      } else {
        await pbService.menu.createMenuItem(
          name: name,
          price: price,
          category: category,
          inStock: _inStock,
          unit: unit,
          description: description,
          image: imageFile,
          cost: cost,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã lưu món "${name}" thành công!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true); // Trả về true để refresh
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi lưu: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // --- HÀM MỚI: SỬA GIÁ BÁN ---
  Future<void> _showEditPriceDialog() async {
    _priceController.text = _currentPrice.toStringAsFixed(
      0,
    ); // Cập nhật controller

    final newPriceString = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cập nhật Giá bán'),
        content: TextField(
          controller: _priceController,
          decoration: const InputDecoration(
            labelText: 'Giá bán (VND)',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(_priceController.text);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (newPriceString != null) {
      setState(() {
        _currentPrice = double.tryParse(newPriceString) ?? _currentPrice;
      });
    }
  }

  // --- HÀM MỚI: ĐI TỚI MÀN HÌNH CÔNG THỨC ---
  void _manageRecipe() async {
    if (!_isEditing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng lưu món ăn trước khi thêm công thức.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            RecipeManagementScreen(menuItem: widget.menuItem!),
      ),
    );

    try {
      final updatedItem = await pbService.menu.getMenuItem(widget.menuItem!.id);
      setState(() {
        _currentCost = updatedItem.cost;
      });
    } catch (e) {
      print('Lỗi tải lại giá vốn: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Sửa Món' : 'Thêm Món Mới'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildImagePicker(),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Tên món',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Vui lòng nhập tên món';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // --- SỬA LỖI 2: THAY GIÁ BÁN TEXTFIELD BẰNG LISTTILE ---
            ListTile(
              title: const Text('Giá bán'),
              subtitle: Text(formatCurrency(_currentPrice)),
              trailing: const Icon(Icons.edit, color: Colors.blue),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.shade400),
              ),
              onTap: _showEditPriceDialog,
            ),

            const SizedBox(height: 16),

            // --- NÚT QUẢN LÝ CÔNG THỨC ---
            ListTile(
              title: const Text('Giá vốn (tự động)'),
              subtitle: Text(formatCurrency(_currentCost)), // <-- SỬA LỖI 1
              trailing: const Icon(Icons.chevron_right),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.shade400),
              ),
              onTap: _manageRecipe,
            ),

            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedUnit,
              decoration: const InputDecoration(
                labelText: 'Đơn vị',
                border: OutlineInputBorder(),
              ),
              items: MENU_ITEM_UNITS
                  .map(
                    (unit) => DropdownMenuItem(value: unit, child: Text(unit)),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedUnit = value;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Vui lòng chọn đơn vị';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<MenuItemCategory>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Phân loại',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: MenuItemCategory.food,
                  child: Text('Món ăn'),
                ),
                DropdownMenuItem(
                  value: MenuItemCategory.drink,
                  child: Text('Thức uống'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedCategory = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Mô tả (không bắt buộc)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Còn hàng'),
              value: _inStock,
              onChanged: (value) {
                setState(() {
                  _inStock = value;
                });
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(_isLoading ? 'Đang lưu...' : 'Lưu'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              onPressed: _isLoading ? null : _submitForm,
            ),
          ],
        ),
      ),
    );
  }

  // --- SỬA LỖI 3: SỬA GIAO DIỆN HÌNH ẢNH ---
  Widget _buildImagePicker() {
    return Center(
      child: Column(
        children: [
          // Bỏ Container cố định chiều cao
          Container(
            width: double.infinity, // Full width
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade100,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildImage(),
            ),
          ),
          TextButton.icon(
            icon: const Icon(Icons.image),
            label: Text(_selectedImage != null ? 'Đổi ảnh khác' : 'Chọn ảnh'),
            onPressed: _pickImage,
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    if (_selectedImage != null) {
      return Image.file(
        File(_selectedImage!.path),
        fit: BoxFit.fitWidth, // <-- Sửa: Không cắt ảnh
        width: double.infinity,
      );
    }
    if (_existingImageUrl != null) {
      return Image.network(
        _existingImageUrl!,
        fit: BoxFit.fitWidth, // <-- Sửa: Không cắt ảnh
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image, size: 100, color: Colors.grey),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const SizedBox(
            height: 200, // Giữ chiều cao tạm thời khi loading
            child: Center(child: CircularProgressIndicator()),
          );
        },
      );
    }
    return const SizedBox(
      height: 150, // Chiều cao mặc định khi chưa có ảnh
      child: Icon(Icons.no_photography, size: 50, color: Colors.grey),
    );
  }
}
