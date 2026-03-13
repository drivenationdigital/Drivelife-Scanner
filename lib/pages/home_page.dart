import 'package:flutter/material.dart';
import 'package:ticket_scanner/pages/login_page.dart';
import '../routes.dart';
import '../services/api_service.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _handleLogout(BuildContext context) async {
    await ApiService().logout();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ApiService().currentUser;
    final theme = Theme.of(context);

    return PopScope(
      canPop: false, // back button does nothing on home
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Top bar ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // App icon + title
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(
                                0.15,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.qr_code_scanner_rounded,
                              color: theme.colorScheme.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Ticket Scanner',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      // Logout
                      GestureDetector(
                        onTap: () => _handleLogout(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A2E),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF1E1E1E)),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.logout_rounded,
                                color: Colors.white54,
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Logout',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // ── Greeting ─────────────────────────────────────
                if (user != null) ...[
                  Text(
                    'Hello, ${user.displayName.split(' ').first} 👋',
                    style: const TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                ],
                const Text(
                  'Ready to\nscan tickets?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    height: 1.15,
                  ),
                ),

                const SizedBox(height: 48),

                // ── Big scan button ───────────────────────────────
                _ScanButton(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.scanner),
                ),

                const SizedBox(height: 20),

                // ── Hint text ─────────────────────────────────────
                const Text(
                  'Point your camera at the QR code on any ticket to verify entry.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),

                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanButton extends StatefulWidget {
  final VoidCallback onTap;
  const _ScanButton({required this.onTap});

  @override
  State<_ScanButton> createState() => _ScanButtonState();
}

class _ScanButtonState extends State<_ScanButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
    _scale = _controller;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(_) => _controller.reverse();
  void _onTapUp(_) {
    _controller.forward();
    widget.onTap();
  }

  void _onTapCancel() => _controller.forward();

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: Container(
          height: 180,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFAE9159), Color.fromARGB(255, 179, 164, 134)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFAE9159).withOpacity(0.45),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.qr_code_scanner_rounded,
                color: Colors.white,
                size: 56,
              ),
              SizedBox(height: 14),
              Text(
                'Scan Now',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
