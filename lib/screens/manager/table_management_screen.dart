import 'package:flutter/material.dart';
import 'package:myshop/models/table.dart';
import 'package:myshop/services/pocketbase_service.dart';

class TableManagementScreen extends StatefulWidget {
  const TableManagementScreen({super.key});

  @override
  State<TableManagementScreen> createState() => _TableManagementScreenState();
}

class _TableManagementScreenState extends State<TableManagementScreen> {
  final PocketBaseService pbService = PocketBaseService.instance;
  late Future<List<TableModel>> _tablesFuture;

  static const List<String> _tableStatuses = ['empty', 'occupied'];

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  void _loadTables() {
    setState(() {
      _tablesFuture = pbService.getTables();
    });
  }

  Future<void> _refresh() async {
    _loadTables();
    try {
      await _tablesFuture;
    } catch (_) {
      // UI will show error state.
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'occupied':
        return 'Có khách';
      case 'empty':
      default:
        return 'Trống';
    }
  }

  Future<void> _openTableForm({TableModel? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _TableFormDialog(existing: existing),
    );
    if (saved == true) {
      _loadTables();
    }
  }

  Future<void> _confirmDelete(TableModel table) async {
    final rootContext = context;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Xóa bàn'),
          content: Text('Xóa "${table.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    try {
      await pbService.deleteTable(table.id);
      _loadTables();
      if (!mounted) return;
      ScaffoldMessenger.of(rootContext).showSnackBar(
        SnackBar(
          content: Text('Đã xóa ${table.name}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(rootContext).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Bàn'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openTableForm(),
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<TableModel>>(
        future: _tablesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Lỗi tải danh sách bàn: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _refresh,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          }

          final tables = snapshot.data ?? [];
          if (tables.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  Padding(
                    padding: EdgeInsets.only(top: 140),
                    child: Center(child: Text('Chưa có bàn nào trong CSDL.')),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              itemCount: tables.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final table = tables[index];

                return ListTile(
                  leading: Icon(
                    Icons.table_restaurant,
                    color: table.isOccupied ? Colors.red : Colors.green,
                  ),
                  title: Text(table.name),
                  subtitle: Text(
                    'Trạng thái: ${_statusLabel(table.status)} • ID: ${table.id}',
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: 'Sửa',
                        icon: const Icon(Icons.edit),
                        onPressed: () => _openTableForm(existing: table),
                      ),
                      IconButton(
                        tooltip: 'Xóa',
                        icon: const Icon(Icons.delete),
                        onPressed: () => _confirmDelete(table),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _TableFormDialog extends StatefulWidget {
  final TableModel? existing;
  const _TableFormDialog({required this.existing});

  @override
  State<_TableFormDialog> createState() => _TableFormDialogState();
}

class _TableFormDialogState extends State<_TableFormDialog> {
  final PocketBaseService pbService = PocketBaseService.instance;
  late final TextEditingController _nameController;
  late String _status;
  bool _isSaving = false;

  static const List<String> _tableStatuses = ['empty', 'occupied'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _status = widget.existing?.status ?? 'empty';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'occupied':
        return 'Có khách';
      case 'empty':
      default:
        return 'Trống';
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập tên bàn'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final existing = widget.existing;
      if (existing == null) {
        await pbService.createTable(name: name, status: _status);
      } else {
        await pbService.updateTable(
          id: existing.id,
          name: name,
          status: _status,
        );
      }

      if (!context.mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Thêm bàn' : 'Sửa bàn'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Tên bàn',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
            enabled: !_isSaving,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(
              labelText: 'Trạng thái',
              border: OutlineInputBorder(),
            ),
            items: _tableStatuses
                .map(
                  (s) =>
                      DropdownMenuItem(value: s, child: Text(_statusLabel(s))),
                )
                .toList(),
            onChanged: _isSaving
                ? null
                : (v) {
                    if (v == null) return;
                    setState(() => _status = v);
                  },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: Text(_isSaving ? 'Đang lưu...' : 'Lưu'),
        ),
      ],
    );
  }
}
