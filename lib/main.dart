import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'routes/app_routes.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/menu_provider.dart';
import 'providers/order_provider.dart';
import 'providers/user_provider.dart';
import 'providers/notification_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env"); // load biến môi trường POCKETBASE_URL
  } catch (_) {
    // Ignore when .env is missing (fallback URL is used).
  }
  // --- THÊM DÒNG NÀY ĐỂ KHỞI TẠO TIẾNG VIỆT ---
  await initializeDateFormatting('vi_VN', null);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => MenuProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: MaterialApp(
        title: 'Quản lý nhà hàng',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          fontFamily: 'Noto Sans',
          textTheme: GoogleFonts.notoSansTextTheme().apply(
            bodyColor: Colors.black87,
            displayColor: Colors.black,
          ),
          scaffoldBackgroundColor: Colors.white,
          textSelectionTheme: TextSelectionThemeData(
            selectionColor: Colors.blue.withOpacity(0.3),
            selectionHandleColor: Colors.blue,
          ),
        ),
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
          '/register': (context) => const RegisterScreen(),
          ...AppRoutes.routes, // các route employeeHome, managerHome
        },
      ),
    );
  }
}
