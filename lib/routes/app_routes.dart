import 'package:flutter/material.dart';
import '../screens/employee/employee_home.dart';
import '../screens/manager/manager_home.dart';

class AppRoutes {
  static final routes = <String, WidgetBuilder>{
    '/employeeHome': (context) => const EmployeeHome(),
    '/managerHome': (context) => const ManagerHome(),
    // Add more routes later
  };
}
