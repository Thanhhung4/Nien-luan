import 'package:flutter/material.dart';
import 'package:myshop/models/table.dart';
import 'package:myshop/widgets/table_card.dart'; // Import widget con

class TableGridView extends StatelessWidget {
  final List<TableModel> tables;
  final Future<void> Function() onRefresh;
  final void Function(TableModel) onTableTapped;

  const TableGridView({
    super.key,
    required this.tables,
    required this.onRefresh,
    required this.onTableTapped,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: GridView.builder(
        padding: const EdgeInsets.all(12.0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 1.0,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: tables.length,
        itemBuilder: (context, index) {
          final table = tables[index];
          return TableCard(
            table: table,
            onTap: () => onTableTapped(table), // Truyền callback
          );
        },
      ),
    );
  }
}
