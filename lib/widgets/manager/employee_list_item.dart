import 'package:flutter/material.dart';
import 'package:myshop/models/staff_profile.dart';

class EmployeeListItem extends StatelessWidget {
  final StaffProfile profile;
  final Future<bool> Function(StaffProfile) onDeleteConfirmed;
  final VoidCallback onTap;

  const EmployeeListItem({
    super.key,
    required this.profile,
    required this.onDeleteConfirmed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(profile.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red.shade700,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: const Icon(Icons.delete_sweep, color: Colors.white),
      ),
      confirmDismiss: (direction) => onDeleteConfirmed(profile),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.indigo.shade100,
          child: Text(
            (profile.name.isNotEmpty ? profile.name[0] : '?').toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.indigo.shade700,
            ),
          ),
        ),
        title: Text(
          profile.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        // ❌ Không còn hiển thị Gmail
        subtitle: Text(profile.role.display),
        trailing: Icon(Icons.chevron_right, color: Colors.grey.shade600),
        onTap: onTap,
      ),
    );
  }
}
