import 'package:flutter/material.dart';
import '../screens/employee/employee_home.dart';
import '../screens/manager/manager_home.dart';

class AppRoutes {
  static final routes = <String, WidgetBuilder>{
    '/employeeHome': (context) => const EmployeeHome(),
    '/managerHome': (context) => const ManagerHome(),
    // Order routes are handled by push navigation instead of named routes
    // because they require parameters (cart items, total price)
  };
}
