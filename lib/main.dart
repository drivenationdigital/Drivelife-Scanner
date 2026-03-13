import 'package:flutter/material.dart';
import 'routes.dart';
import 'services/api_service.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final hasSession = await ApiService().tryRestoreSession();
  runApp(TicketScannerApp(hasSession: hasSession));
}

class TicketScannerApp extends StatelessWidget {
  final bool hasSession;

  const TicketScannerApp({super.key, required this.hasSession});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ticket Scanner',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      // Use home: instead of initialRoute — this sets a single root
      // with nothing beneath it, so back never leaks to login
      home: hasSession ? const HomePage() : const LoginPage(),
      routes: AppRoutes.routes,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }

  ThemeData _buildTheme() {
    const Color primary = Color(0xFFAE9159);
    const Color background = Color(0xFF0F0F1A);
    const Color surface = Color(0xFF1A1A2E);
    const Color onSurface = Color(0xFFE0E0F0);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        background: background,
        surface: surface,
        onSurface: onSurface,
        onPrimary: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF1E1E1E), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        hintStyle: TextStyle(color: onSurface.withOpacity(0.4)),
        labelStyle: const TextStyle(color: onSurface),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: onSurface,
        ),
        bodyMedium: TextStyle(fontSize: 15, color: onSurface),
        labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }
}
