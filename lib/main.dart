import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'routes/app_routes.dart';
import 'screens/auth/login_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env"); // load biến môi trường POCKETBASE_URL
  // --- THÊM DÒNG NÀY ĐỂ KHỞI TẠO TIẾNG VIỆT ---
  await initializeDateFormatting('vi_VN', null);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quản lý nhà hàng',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      // --- THÊM CÁC DÒNG NÀY ĐỂ CẤU HÌNH LOCALE ---
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('vi', 'VN'), // Hỗ trợ Tiếng Việt
        Locale('en', ''), // (Dự phòng)
      ],
      // --- KẾT THÚC THÊM ---
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        ...AppRoutes.routes, // các route employeeHome, managerHome
      },
    );
  }
}
