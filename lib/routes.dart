import 'package:flutter/material.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/scanner_page.dart';
import 'pages/result_page.dart';

class AppRoutes {
  static const String login = '/';
  static const String home = '/home';
  static const String scanner = '/scanner';
  static const String result = '/result';

  static Map<String, WidgetBuilder> get routes => {
    home: (_) => const HomePage(),
    scanner: (_) => const ScannerPage(),
  };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    if (settings.name == login) {
      return MaterialPageRoute(builder: (_) => const LoginPage());
    }
    if (settings.name == result) {
      final args = settings.arguments as Map<String, dynamic>? ?? {};
      return MaterialPageRoute(builder: (_) => ResultPage(scanData: args));
    }
    return null;
  }
}
