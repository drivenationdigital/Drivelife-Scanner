import 'package:flutter/material.dart';
import 'package:ticket_scanner/pages/login_page.dart';
import 'package:ticket_scanner/pages/search_page.dart';
import '../routes.dart';
import '../services/api_service.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
                      Row(
                        children: [
                          Container(
                            width: 150,
                            height: 60,
                            child: SvgPicture.asset(
                              'assets/logo.svg',
                              width: 40,
                              height: 40,
                            ),
                          ),
                          // const SizedBox(width: 12),
                          // const Text(
                          //   'Ticket Scanner',
                          //   style: TextStyle(
                          //     color: Colors.white,
                          //     fontSize: 18,
                          //     fontWeight: FontWeight.bold,
                          //   ),
                          // ),
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

                const SizedBox(height: 32),

                // ── Heading ─────────────────────────────────────
                const Text(
                  'Ready to\nscan tickets?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    height: 1.15,
                  ),
                ),

                const SizedBox(height: 32),

                // ── Scan ────────────────────────────────────────
                _ActionButton(
                  icon: Icons.qr_code_scanner_rounded,
                  label: 'Scan Now',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.scanner),
                ),

                const SizedBox(height: 20),

                // ── Search ──────────────────────────────────────
                _ActionButton(
                  icon: Icons.search_rounded,
                  label: 'Search',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SearchPage()),
                  ),
                ),

                const Spacer(),

                // ── Support footer ──────────────────────────────
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Column(
                    children: [
                      Text(
                        'For all support queries, please phone',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      Text(
                        '(+44) 0800 488 0720',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Reusable big gold action button (was _ScanButton)
// ─────────────────────────────────────────────────────────────────
class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double height;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.height = 160,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton>
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
          height: widget.height,
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: Colors.white, size: 52),
              const SizedBox(height: 12),
              Text(
                widget.label,
                style: const TextStyle(
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
