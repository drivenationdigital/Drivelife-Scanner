import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../routes.dart';
import '../services/api_service.dart';
import 'login_page.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  bool _isProcessing = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcode = capture.barcodes.firstOrNull;
    final rawValue = barcode?.rawValue;
    print('Detected barcode: $rawValue');
    if (rawValue == null || rawValue.isEmpty) return;

    setState(() => _isProcessing = true);
    await _cameraController.stop();

    if (!mounted) return;

    // Pre-fetch the ticket before navigating so we can intercept
    // a session expiry and redirect straight to login
    // final result = await ApiService().lookupTicket(rawValue);

    if (!mounted) return;

    // if (result.sessionExpired) {
    //   // Token expired — clear everything and send to login
    //   Navigator.pushAndRemoveUntil(
    //     context,
    //     MaterialPageRoute(builder: (_) => const LoginPage()),
    //     (route) => false,
    //   );
    //   return;
    // }

    await Navigator.pushNamed(
      context,
      AppRoutes.result,
      arguments: {'raw': rawValue},
    );

    if (!mounted) return;
    setState(() => _isProcessing = false);
    await _cameraController.start();
  }

  Future<void> _handleLogout() async {
    await ApiService().logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  void _goBack() => Navigator.pop(context);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Full-screen camera ──────────────────────────────
          MobileScanner(controller: _cameraController, onDetect: _onDetect),

          // ── Dark vignette overlay ───────────────────────────
          _ScanOverlay(),

          // ── Top bar ─────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  // Back button
                  _IconBtn(
                    icon: Icons.arrow_back_rounded,
                    onTap: _goBack,
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Scan Ticket',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Point camera at QR code',
                          style: TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  // Torch
                  _IconBtn(
                    icon: Icons.flashlight_on_rounded,
                    onTap: () => _cameraController.toggleTorch(),
                    tooltip: 'Toggle torch',
                  ),
                ],
              ),
            ),
          ),

          // ── Scan frame ───────────────────────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: const _ScanFrame(),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    _isProcessing
                        ? 'Looking up ticket…'
                        : 'Align QR code within frame',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Processing overlay ───────────────────────────────
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFFAE9159)),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────

class _ScanOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _OverlayPainter(), child: const SizedBox.expand());
}

class _OverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const frameSize = 260.0;
    final left = (size.width - frameSize) / 2;
    final top = (size.height - frameSize) / 2;
    final paint = Paint()..color = Colors.black.withOpacity(0.55);

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, top), paint);
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        top + frameSize,
        size.width,
        size.height - top - frameSize,
      ),
      paint,
    );
    canvas.drawRect(Rect.fromLTWH(0, top, left, frameSize), paint);
    canvas.drawRect(
      Rect.fromLTWH(
        left + frameSize,
        top,
        size.width - left - frameSize,
        frameSize,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScanFrame extends StatelessWidget {
  const _ScanFrame();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 260,
    height: 260,
    child: CustomPaint(
      painter: _FramePainter(
        cornerSize: 28,
        thickness: 4,
        color: const Color(0xFFAE9159),
      ),
    ),
  );
}

class _FramePainter extends CustomPainter {
  final double cornerSize;
  final double thickness;
  final Color color;

  const _FramePainter({
    required this.cornerSize,
    required this.thickness,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;
    final c = cornerSize;

    canvas.drawPath(
      Path()
        ..moveTo(0, c)
        ..lineTo(0, 0)
        ..lineTo(c, 0),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w - c, 0)
        ..lineTo(w, 0)
        ..lineTo(w, c),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, h - c)
        ..lineTo(0, h)
        ..lineTo(c, h),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w - c, h)
        ..lineTo(w, h)
        ..lineTo(w, h - c),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _IconBtn({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
