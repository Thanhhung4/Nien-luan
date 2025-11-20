import 'package:flutter/material.dart';
import 'package:myshop/models/table.dart';

class TableCard extends StatelessWidget {
  final TableModel table;
  final VoidCallback onTap;

  const TableCard({super.key, required this.table, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Xác định màu sắc dựa trên trạng thái
    final Color cardColor = table.isOccupied
        ? Colors.red.shade400
        : Colors.green.shade400;
    const Color textColor = Colors.white;

    return InkWell(
      onTap: onTap,
      splashColor: Colors.white.withOpacity(0.4),
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 4.0,
        color: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                table.isOccupied ? Icons.restaurant : Icons.event_seat,
                color: textColor,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                table.name,
                style: const TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                table.displayStatus,
                style: TextStyle(
                  color: textColor.withOpacity(0.9),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
